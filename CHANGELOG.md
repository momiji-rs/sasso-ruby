# Changelog

All notable changes to the **sasso** Ruby gem are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

The gem version floats independently of the `sasso` compiler crate; each release
notes the exact core crate version it pins.

## [Unreleased]

## [0.2.7] - 2026-06-25

### Changed

- Adopt core **sasso 0.6.3** (recompile-only; the gem's Ruby API is unchanged).
  `Sasso.compile`/`Sasso.compile_string` now return the serialized stylesheet
  with **no trailing newline**, byte-for-byte matching dart-sass's library API
  (`sass` embedded / `compileString().css`). Previously expanded output carried
  a stray trailing newline; compressed output is unchanged (it never had one).
  If you write the result straight to a `.css` file and want the conventional
  trailing newline, append `"\n"` yourself (most asset pipelines already do).

## [0.2.6] - 2026-06-25

### Changed

- Adopt core **sasso 0.6.2** (recompile-only; the gem's Ruby API is unchanged).
  Picks up the upstream fix where **compressed** output now emits the shortest
  equivalent legacy-color form, matching dart-sass 1.101.0. A computed color such
  as `darken(#336699, 10%)` now compiles to `hsl(210,50%,30%)` instead of the
  longer `rgb(38.25,76.5,114.75)`, and an integer-rgb-equivalent hsl literal
  (`hsl(210, 50%, 40%)`) collapses to `#369`. Expanded output is unchanged.

## [0.2.5] - 2026-06-16

### Changed

- Adopt core **sasso 0.6.1** (recompile-only; the gem's Ruby API is unchanged).
  Picks up the upstream fix where a relative `meta.load-css` inside a first-class
  mixin (`meta.get-mixin` + `meta.apply`) resolves against the mixin's defining
  file rather than the caller's.

## [0.2.4] - 2026-06-15

### Changed

- Adopt core **sasso 0.6.0**. The core release is a breaking change to the
  Rust `Importer` trait (two-phase `canonicalize`/`load`), but the gem exposes
  **no userland importer** — it builds the built-in `FsImporter` only — so this
  is a recompile-only bump with **no change to the gem's Ruby API** (the same
  `Sasso.compile` / `Sasso.compile_string` with `load_paths:` / `source_map:`).

## [0.2.3] - 2026-06-15

Adopts core crate **v0.5.3**.

### Fixed

- Via core v0.5.3: a `!default` assignment no longer evaluates its right-hand
  side when the variable already holds a non-null value (dart-sass
  short-circuits first), fixing a spurious "incompatible units" error in
  Bootstrap-on-Shopware setups.
- Via core v0.5.3: legacy `rgb()`/`hsl()` now preserve the caller's
  `rgba`/`hsla` spelling in special-value passthroughs (e.g.
  `rgba(var(--bs-body-color-rgb), …)`), matching dart-sass instead of
  normalizing the name down to `rgb`/`hsl`.

## [0.2.2] - 2026-06-14

Adopts core crate **v0.5.2**.

### Fixed

- Via core v0.5.2: expanded output now emits dart-faithful `@at-root`
  group-separation blank lines — one blank at a hoist→resume boundary that ends
  in a style rule, with nested-`@at-root` chains and a rule + its own bubbled
  `@media` kept contiguous (no more missing or over-emitted blanks). Byte-exact
  to dart-sass; compressed output is unaffected.

## [0.2.1] - 2026-06-14

Adopts core crate **v0.5.1**.

### Fixed

- Via core v0.5.1: source maps now map the `@media`/`@at-root`/`@supports`
  bubbled parent selector and the `@supports` header, byte-exact to dart-sass —
  fixing a 0.5.0 (= gem 0.2.0 pinned 0.4.0) compressed-map gap for `@media`/
  `@at-root`-bubbled rules. Compressed output also gains dart-faithful whitespace
  for `@media`/`@supports` preludes (`@media(min-width: 1px)`, `(a)and (b)`).

## [0.2.0] - 2026-06-14

Adopts core crate **v0.4.0**.

### Added

- **Source map support.** `Sasso.compile_string(source, source_map: true)` (and
  `Sasso.compile(path, source_map: true)`) returns a `Sasso::CompileResult` with
  `#css` (the CSS String) and `#source_map` (the Source Map v3 as a parsed Hash:
  `"version" => 3`, `"mappings"`, `"sources"`, …). Pass
  `source_map_include_sources: true` to embed the full source text in the map's
  `sourcesContent`. Without `source_map:` the methods still return a plain CSS
  String (backwards compatible). The mappings are byte-identical to dart-sass.

## [0.1.2] - 2026-06-13

Adopts core crate **v0.3.1**.

### Changed

- Relicensed to **MIT** only (was MIT OR Apache-2.0), matching the Sass
  ecosystem. The core `sasso` compiler crate remains dual MIT OR Apache-2.0.
  Already-published gem versions retain their original license.

### Fixed

- Via core v0.3.1: compressed output now emits a color's canonical CSS name when
  it is no longer than the shortest hex (`red` not `#f00`, `aqua` not `#0ff`),
  matching dart-sass.

## [0.1.1] - 2026-06-13

Pins the same core crate **v0.3.0**.

### Fixed

- `Sasso.compile(path)` now searches the entry file's own directory FIRST for
  relative `@use`/`@forward`/`@import` (the `sass` CLI convention), so a file on
  disk can import its sibling partials without the caller spelling out
  `load_paths:`. An explicit `load_paths:` is still honored, after the
  implicit entry-file directory.

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
