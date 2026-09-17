//! Magnus binding around `sasso::compile`. Exposes a flat native ABI
//! `Sasso::Native._compile(source, opts)`; the ergonomic keyword API lives in
//! `lib/sasso.rb`. The core crate is `unsafe`-free; this thin FFI layer is the
//! `unsafe` boundary (magnus hides it — we write no explicit `unsafe`).
//!
//! Options travel in ONE hash rather than as positional arguments, so adopting
//! a new compiler option costs a key here instead of an ABI arity change on
//! both sides. `Sasso::Native` is a private ABI: `lib/sasso.rb` is its only
//! caller and validates every value before it arrives.
//!
//! Importer policy (v1): a built-in Rust `FsImporter` driven by `load_paths`.
//! A Ruby-callback importer is deferred (GC-pinning + GVL re-entrancy hazards).

use magnus::{function, prelude::*, value::ReprValue, Error, RArray, RHash, Ruby, TryConvert};
use sasso_core as sasso; // the core crate, renamed in Cargo.toml to free the `sasso` package name
use std::cell::RefCell;
use std::path::PathBuf;
use std::rc::Rc;

/// Read one option out of the hash. A missing key and an explicit `nil` read
/// the same, so the Ruby wrapper can pass a key through unconditionally.
fn opt<T: TryConvert>(ruby: &Ruby, opts: RHash, key: &str) -> Result<Option<T>, Error> {
    match opts.get(ruby.sym_new(key)) {
        Some(v) if !v.is_nil() => Ok(Some(T::try_convert(v)?)),
        _ => Ok(None),
    }
}

/// Read a boolean option, falling back to the core crate's own default.
fn flag(ruby: &Ruby, opts: RHash, key: &str, default: bool) -> Result<bool, Error> {
    Ok(opt::<bool>(ruby, opts, key)?.unwrap_or(default))
}

/// Read `load_paths` as filesystem paths.
fn load_paths(ruby: &Ruby, opts: RHash) -> Result<Vec<PathBuf>, Error> {
    match opt::<RArray>(ruby, opts, "load_paths")? {
        Some(a) => Ok(a
            .to_vec::<String>()?
            .into_iter()
            .map(PathBuf::from)
            .collect()),
        None => Ok(Vec::new()),
    }
}

/// One `@warn` / `@debug` / deprecation diagnostic, copied out of the borrowed
/// `WarnEvent` so it outlives the compile that produced it.
///
/// The handler runs DURING the compile, and calling back into Ruby from there
/// would re-enter the VM mid-compile; instead every event is recorded here and
/// handed to Ruby once `compile` has returned.
struct Warning {
    kind: &'static str,
    deprecation: bool,
    deprecation_id: String,
    message: String,
    formatted: String,
    url: String,
    line: usize,
    path: String,
}

impl Warning {
    fn record(event: &sasso::WarnEvent<'_>) -> Self {
        Warning {
            kind: match event.kind {
                sasso::WarnKind::Debug => "debug",
                sasso::WarnKind::Warn => "warn",
            },
            deprecation: event.deprecation,
            deprecation_id: event.deprecation_id.to_owned(),
            message: event.message.to_owned(),
            formatted: event.formatted.to_owned(),
            url: event.url.to_owned(),
            line: event.line,
            path: event.path.to_owned(),
        }
    }

    fn into_hash(self, ruby: &Ruby) -> Result<RHash, Error> {
        let h = ruby.hash_new();
        h.aset(ruby.sym_new("kind"), ruby.sym_new(self.kind))?;
        h.aset(ruby.sym_new("deprecation"), self.deprecation)?;
        h.aset(ruby.sym_new("deprecation_id"), self.deprecation_id)?;
        h.aset(ruby.sym_new("message"), self.message)?;
        h.aset(ruby.sym_new("formatted"), self.formatted)?;
        h.aset(ruby.sym_new("url"), self.url)?;
        h.aset(ruby.sym_new("line"), self.line)?;
        h.aset(ruby.sym_new("path"), self.path)?;
        Ok(h)
    }
}

/// Flat native ABI:
/// `_compile(source, opts) -> [css, source_map_json, warnings, error]`.
///
/// A compile failure RETURNS its message in `error` rather than raising here,
/// so the recorded warnings come back with it: `lib/sasso.rb` delivers them to
/// `on_warn:` and then raises `Sasso::CompileError`. dart-sass's logger sees the
/// warnings a failing compile raised too, and swallowing them would be worse
/// than not forwarding them — under `on_warn:` nothing else prints them.
/// Never panics across FFI — every other failure is a raised Ruby exception.
fn native_compile(ruby: &Ruby, source: String, opts: RHash) -> Result<RArray, Error> {
    let style = opt::<String>(ruby, opts, "style")?.unwrap_or_default();
    let syntax = opt::<String>(ruby, opts, "syntax")?.unwrap_or_default();
    let url = opt::<String>(ruby, opts, "url")?;
    let paths = load_paths(ruby, opts)?;
    let want_map = flag(ruby, opts, "source_map", false)?;

    let mut copts = sasso::Options::default()
        .with_style(if style == "compressed" {
            sasso::OutputStyle::Compressed
        } else {
            sasso::OutputStyle::Expanded
        })
        .with_syntax(match syntax.as_str() {
            "sass" => sasso::Syntax::Sass,
            "css" => sasso::Syntax::Css,
            _ => sasso::Syntax::Scss,
        })
        .with_unicode(flag(ruby, opts, "unicode", true)?)
        .with_source_map_include_sources(flag(ruby, opts, "source_map_include_sources", false)?)
        .with_charset(flag(ruby, opts, "charset", true)?);

    // `url` is load-bearing: it ENABLES the byte-exact dart diagnostic block.
    if let Some(ref u) = url {
        copts = copts.with_url(u);
    }

    // Bind the importer for the whole `compile` call (Options borrows it).
    let importer = sasso::FsImporter::new(paths.clone());
    if !paths.is_empty() {
        copts = copts.with_importer(&importer);
    }

    // dart-sass `quietDeps`: classified by how a file was RESOLVED, so the set
    // has to come from the importer that resolved it. Harmless with no load
    // paths — nothing can be a dependency, so the set stays empty.
    if flag(ruby, opts, "quiet_deps", false)? {
        copts = copts.with_quiet_deps(importer.dependencies());
    }

    // "stderr" leaves `Options::warn` unset, which is what makes the core print
    // its own dart-style block — the default path installs no handler and pays
    // nothing. Only "capture" allocates.
    let captured: Rc<RefCell<Vec<Warning>>> = Rc::new(RefCell::new(Vec::new()));
    match opt::<String>(ruby, opts, "warnings")?
        .unwrap_or_default()
        .as_str()
    {
        "silence" => copts = copts.with_warn_handler(Rc::new(|_| {})),
        "capture" => {
            let sink = Rc::clone(&captured);
            copts = copts.with_warn_handler(Rc::new(move |event: &sasso::WarnEvent<'_>| {
                sink.borrow_mut().push(Warning::record(event));
            }));
        }
        _ => {}
    }

    // One shape for both entry points: the map is None when it was not asked for.
    let compiled = if want_map {
        sasso::compile_with_source_map(&source, &copts)
            .map(|result| (result.css, Some(result.source_map.to_json())))
    } else {
        sasso::compile(&source, &copts).map(|css| (css, None))
    };

    let out = ruby.ary_new_capa(4);
    let error = match compiled {
        Ok((css, map_json)) => {
            out.push(css)?;
            out.push(map_json)?;
            None
        }
        // Report the failure as a value; `lib/sasso.rb` raises it, AFTER the
        // warnings below have been delivered.
        Err(e) => {
            out.push(ruby.qnil())?;
            out.push(ruby.qnil())?;
            Some(e.to_string())
        }
    };

    // Only ever non-empty under "capture".
    let recorded = captured.take();
    let warnings = ruby.ary_new_capa(recorded.len());
    for warning in recorded {
        warnings.push(warning.into_hash(ruby)?)?;
    }
    out.push(warnings)?;
    out.push(error)?;

    Ok(out)
}

/// The bundled core compiler's version, read from the crate this extension is
/// actually linked against. The core exposes `VERSION` (since 0.9.1) precisely
/// so a binding cannot report a version that has drifted from its own pin.
fn core_version() -> &'static str {
    sasso::VERSION
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Sasso")?;
    let native = module.define_module("Native")?;
    native.define_module_function("_compile", function!(native_compile, 2))?;
    native.define_module_function("_core_version", function!(core_version, 0))?;
    Ok(())
}
