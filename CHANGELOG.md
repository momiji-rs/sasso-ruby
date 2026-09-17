# Changelog

All notable changes to the **sasso** Ruby gem are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Since 0.14.0 the gem version tracks the `sasso` compiler crate it bundles; each
release notes the exact core crate version it pins. Releases up to 0.2.7 versioned
the gem independently of the crate.

## [Unreleased]

## [0.14.0] - 2026-09-17

_The gem version now tracks the core compiler's. It jumps 0.2.7 → 0.14.0 to meet
`sasso` 0.14.0, adopting seven core releases at once (0.7.0 through 0.14.0)._

_**Why align.** The gem version floated independently, so "sasso 0.2.7" said
nothing about which compiler it carried: the three framework gems each had to
document the mapping, and a bug report needed both numbers to be actionable.
From here, a gem release adopting core X.Y.Z **is** gem X.Y.Z. A gem-only fix
takes the next patch, so the gem may sit ahead of the crate within a minor —
the new `Sasso::CORE_VERSION` always reports what is actually linked._

_The Ruby API is backward compatible; the CSS the compiler emits is not, in the
ways listed below._

### Removed

- **Ruby 3.1 support** (`required_ruby_version` is now `>= 3.2.0`). It left
  security maintenance in March 2025, and is off the precompiled-gem matrix.

### Changed (output — dart-sass 1.101.4 → 1.104.1 alignment)

The gem's Ruby API is unchanged, but the CSS it emits moved with the core. If
you byte-compare output — snapshot tests, asset digests, build caches — expect
diffs. The CSS is equivalent; only its spelling changed.

- **Global `whiteness()` / `blackness()` are no longer built-ins** (core 0.9.0):
  they are `sass:color`-only, so the bare call is now an unknown function and
  passes through as plain CSS instead of being evaluated. `whiteness(#f00)` goes
  from `0%` to `whiteness(#f00)`, and `1 + whiteness(#f00)` to `1whiteness(#f00)`
  — both byte-identical to dart-sass 1.104.1, and both **silent**: no error, no
  warning. This is the change in this release to grep your stylesheets for. Use
  `color.whiteness()` / `color.blackness()` via `@use "sass:color"`.
- A legacy color with any fractional channel writes its rgb triple as
  **percentages**: `rgb(127.5, 0, 127.5)` becomes `rgb(50%, 0%, 50%)` (0.9.0).
- **Compressed hsl/hwb route through rgb** like every other legacy space, so
  `darken(#336699, 10%)` compresses to `rgb(15%,30%,45%)` rather than
  `hsl(210,50%,30%)` (0.9.0).
- **A negative zero keeps its sign**: `0 * -1`, `-0` and `math.div(0, -1)`
  serialize as `-0`. The sign is the IEEE sign bit, so `0 - 0` stays `0` (0.10.0).
- **Colors convert their degenerate channels**: a `NaN` channel becomes `0`, and
  a polar hue converts every non-finite value (0.10.0).
- **`rec2020` uses the pure 2.4 gamma transfer function**, replacing the BT.2020
  piecewise curve (0.9.0).
- **Plain-CSS `if()` emits in CSS serialization format**, not `meta.inspect`
  format: lists lose their parens, `null` serializes to nothing (0.9.0).
- **A comment before `@use` is emitted exactly once**; a repeat edge into an
  already-loaded module no longer re-emits it (0.10.0).
- Extensive **`@extend`, module-system and selector line-break fidelity** fixes
  (0.7.0, 0.8.0) — the work that took all 20 projects in the core's real-world
  corpus to byte-identical with dart-sass.

### Changed (source maps)

- **A declaration whose value is a bare `$name` maps back to the variable's
  definition**, transitively through `$b: $a` chains, module members and
  mixin/function parameters (0.9.0). The segment used to be omitted, which also
  renumbered every following delta-encoded segment — so a recorded `mappings`
  string changes.

### Changed (diagnostics)

- **Function arity errors follow dart's wording**: only positional arguments
  count, and the word "positional" appears once any named argument is in play
  (0.10.0).
- **An error inside a loaded file is attributed to that file**, with one stack
  frame per loader, for `@use`, `@forward` and `@import` chains alike (0.7.0).

### Added

- **`charset:`** (dart-sass `charset`) — `false` omits the `@charset "UTF-8";`
  prefix, or the U+FEFF BOM when compressed, that non-ASCII output carries.
- **`quiet:`** — print no `@warn`/`@debug`/deprecation diagnostics. They have
  always gone to `$stderr`; there was previously no way off.
- **`quiet_deps:`** (dart-sass `quietDeps`) — drop deprecation warnings raised
  inside dependencies (files resolved through a load path), while the entry
  stylesheet's own still print. `@warn` is untouched either way.
- **`on_warn:`** — a callable receiving each diagnostic as a Hash of the new
  `Sasso::WARNING_KEYS`, which replaces the stderr printing rather than
  duplicating it. `:formatted` carries the full dart-style block, so the
  compiler's own rendering can go straight into an application logger.
  Mutually exclusive with `quiet:`. A compile that warns and then fails delivers
  its warnings before raising `Sasso::CompileError`, the way dart-sass hands them
  to its logger before throwing.
- **`Sasso::CORE_VERSION`** — the bundled compiler crate's version, read from
  the linked binary so it cannot drift from what is loaded.

### Documentation

- The README documents **`source_map:` and `CompileResult` for the first time**;
  they shipped in gem 0.2.0 and never reached it. `sig/sasso.rbs` gains them too,
  alongside the new options.
- The **Performance table is remeasured**: this working tree (core 0.14.0)
  against `sass-embedded` 1.104.1 and `sassc` 2.4.0. The ~180-rule case is ~10%
  faster. The cold-start row is **corrected upward**, from a claimed 1.1 ms to a
  measured 3.2 ms — that figure reproduced on neither the old gem nor the new, so
  it predates this release; the margin over `sass-embedded` is 12.7×, not 35×.
- `benchmark/Gemfile` takes **`SASSO_PATH`** to benchmark a working tree instead
  of the published gem, which is what the README's table now reports.

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
