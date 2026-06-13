//! Magnus binding around `sasso::compile`. Exposes a flat native ABI
//! `Sasso::Native._compile(...)`; the ergonomic keyword API lives in
//! `lib/sasso.rb`. The core crate is `unsafe`-free; this thin FFI layer is the
//! `unsafe` boundary (magnus hides it — we write no explicit `unsafe`).
//!
//! Importer policy (v1): a built-in Rust `FsImporter` driven by `load_paths`.
//! A Ruby-callback importer is deferred (GC-pinning + GVL re-entrancy hazards).

use magnus::{function, prelude::*, Error, ExceptionClass, RArray, RModule, Ruby};
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

/// Flat native ABI. Args are pre-validated/normalized by the Ruby wrapper.
/// Never panics across FFI — every failure is a raised Ruby exception.
fn native_compile(
    ruby: &Ruby,
    source: String,
    style: String,
    syntax: String,
    load_paths: RArray,
    url: Option<String>,
    unicode: bool,
) -> Result<String, Error> {
    let mut opts = sasso::Options::default()
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
        .with_unicode(unicode);

    // `url` is load-bearing: it ENABLES the byte-exact dart diagnostic block.
    if let Some(ref u) = url {
        opts = opts.with_url(u);
    }

    let paths: Vec<PathBuf> = load_paths
        .to_vec::<String>()?
        .into_iter()
        .map(PathBuf::from)
        .collect();
    // Bind the importer for the whole `compile` call (Options borrows it).
    let importer = sasso::FsImporter::new(paths.clone());
    if !paths.is_empty() {
        opts = opts.with_importer(&importer);
    }

    sasso::compile(&source, &opts).map_err(|e| compile_error(ruby, e.to_string()))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Sasso")?;
    let native = module.define_module("Native")?;
    native.define_module_function("_compile", function!(native_compile, 6))?;
    Ok(())
}
