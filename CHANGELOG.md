# Changelog

All notable changes to the **sasso** Ruby gem are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

The gem version floats independently of the `sasso` compiler crate; each release
notes the exact core crate version it pins.

## [Unreleased]

## [0.1.0] - 2026-06-13

Initial release. In-process SCSS/Sass → CSS via a Rust native extension
(magnus + rb-sys) around the `sasso` crate **v0.3.0**.

### Added

- `Sasso.compile_string(source, **opts)` and `Sasso.compile(path, **opts)` →
  CSS String, with `style:`, `syntax:`/`indented:`, `load_paths:`, `url:`, and
  `alert_ascii:` options.
- `Sasso::CompileError < Sasso::Error < StandardError`, carrying the compiler's
  full diagnostic message.
- Precompiled native gems for common platforms, with a source-compile fallback.
