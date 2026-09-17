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

use magnus::{
    function, prelude::*, value::ReprValue, Error, ExceptionClass, RArray, RHash, RModule, Ruby,
    TryConvert,
};
use sasso_core as sasso; // the core crate, renamed in Cargo.toml to free the `sasso` package name
use std::path::PathBuf;

/// `Sasso::CompileError` (defined in lib/sasso.rb, loaded before this ext) for
/// a rescuable raise; falls back to `RuntimeError` if the lookup ever fails.
fn compile_error(ruby: &Ruby, msg: String) -> Error {
    let klass = ruby
        .class_object()
        .const_get::<_, RModule>("Sasso")
        .and_then(|m| m.const_get::<_, ExceptionClass>("CompileError"))
        .unwrap_or_else(|_| ruby.exception_runtime_error());
    Error::new(klass, msg)
}

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
        Some(a) => Ok(a.to_vec::<String>()?.into_iter().map(PathBuf::from).collect()),
        None => Ok(Vec::new()),
    }
}

/// Flat native ABI: `_compile(source, opts) -> [css, source_map_json_or_nil]`.
/// Never panics across FFI — every failure is a raised Ruby exception.
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
        .with_source_map_include_sources(flag(
            ruby,
            opts,
            "source_map_include_sources",
            false,
        )?);

    // `url` is load-bearing: it ENABLES the byte-exact dart diagnostic block.
    if let Some(ref u) = url {
        copts = copts.with_url(u);
    }

    // Bind the importer for the whole `compile` call (Options borrows it).
    let importer = sasso::FsImporter::new(paths.clone());
    if !paths.is_empty() {
        copts = copts.with_importer(&importer);
    }

    let out = ruby.ary_new_capa(2);
    if want_map {
        let result = sasso::compile_with_source_map(&source, &copts)
            .map_err(|e| compile_error(ruby, e.to_string()))?;
        out.push(result.css)?;
        out.push(result.source_map.to_json())?;
    } else {
        let css = sasso::compile(&source, &copts).map_err(|e| compile_error(ruby, e.to_string()))?;
        out.push(css)?;
        out.push(ruby.qnil())?;
    }
    Ok(out)
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Sasso")?;
    let native = module.define_module("Native")?;
    native.define_module_function("_compile", function!(native_compile, 2))?;
    Ok(())
}
