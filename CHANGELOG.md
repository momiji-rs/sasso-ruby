# Changelog

All notable changes to the **sasso** Ruby gem are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Since 0.14.0 the gem version tracks the `sasso` compiler crate it bundles; each
release notes the exact core crate version it pins. Releases up to 0.2.7 versioned
the gem independently of the crate.

## [Unreleased]

_Adopts core `sasso` 0.21.0, nine core releases at once (0.15.0 through 0.21.0)._

_The Ruby API is backward compatible and gains one option. The compiler is not:
some stylesheets that compiled before now fail, and some CSS changes meaning,
not only bytes. Read **New errors** first, then the output changes marked
**meaning**._

### Added

- **`silence_deprecations:`** (dart-sass `silenceDeprecations`): deprecation ids,
  as Strings or Symbols, whose warnings are dropped wherever they are raised.
  Every other diagnostic still comes through. The core drops a silenced id before
  its repetition cap, so unlike filtering inside `on_warn:` it leaves no
  "N repetitive deprecation warnings omitted" footer. Ids the compiler never
  emits are accepted, as dart accepts them (core 0.17.0).

### Changed (new errors — stylesheets that compiled before)

- **A built-in rejects an argument name it does not declare** (core 0.19.1).
  `math.max(1, 2, $x: 999)` was `999`; it is now `Error: No parameter named $x.`
  The color constructors are not checked yet.
- **An argument given both by position and by name is an error** (0.19.2).
  `color.mix(red, blue, 10%, $color1: green)` was `rgb(10%, 0%, 90%)`; it is now
  `Argument $color1 was passed both by position and by name.`
- **`@use "sass:color" as *` no longer exposes the members dart removed from
  `sass:color`**, so `saturate(#abcdef, 10%)` reached that way fails (0.19.0).
- **The color functions reject `var()`, `env()` and a calc that cannot fold**,
  for example `color.invert(var(--c))` (0.19.0).
- **Plain CSS rejects every `#{…}`**, where some positions used to drop it
  silently, and a style rule inside a keyframe frame of a `.css` file is an
  error (0.19.0).
- **Selectors follow dart's grammar** (0.19.3). Malformed attributes (`[a=1]`,
  `[a==b]`, `[]`), characters that start no selector (`a^b`), invalid keyframe
  stops (`10px`) and a raw line break inside a quoted string now fail.

### Changed (output)

As with 0.14.0, byte-compared output (snapshot tests, asset digests, build
caches) will differ. Entries marked **meaning** change what a browser does.

- **meaning:** **compressed `color()` is valid CSS again** (0.17.0).
  `color(display-p3 0.5 0.2 0.9)` compressed to `color(display-p3.5.2.9)`,
  which browsers drop; it is now `color(display-p3 .5 .2 .9)`.
- **meaning:** **a non-ASCII space is no longer whitespace** (0.19.3). An NBSP
  inside a selector stays part of it: `[a="x<NBSP>y"]` was rewritten to
  `[a="x y"]`, and `a<NBSP>b` became a descendant selector. Output containing one
  now carries `@charset "UTF-8";`.
- **meaning:** **whitespace inside a quoted attribute value is kept**:
  `[a="x   y"]` used to collapse to `[a="x y"]` (0.19.3). A quoted `(` or `[`
  no longer swallows the rest of the selector list.
- **meaning:** **an empty at-rule survives compression**: `@font-face {}`
  compressed to nothing and is now `@font-face{}` (0.19.0).
- **meaning:** **plain `.css` loaded through `@use`/`@import` keeps rules it used
  to drop** (`@keyframes`, a custom `@function`, an at-rule nested in a style
  rule), and stops hoisting at-rules out of a keyframe frame (0.19.0).
- **meaning:** **legacy color edge cases follow dart**. A degenerate color such
  as `hsl(0, 100%, calc(-infinity * 1%))` is a color rather than a string, so
  `color.mix()` on it gives `hsl(0, 0%, 0%)` instead of `rgb(NaN%, NaN%, NaN%)`.
  `color.change()` on an hsl color no longer flips its hue (0.19.0).
- **Compressed colors and numbers serialize the way dart's do**, about 1,400
  cases (0.19.0). For example, `oklab(1% 0 0)` compresses to `oklab(.01 0 0)`.
- **The `rgb()`/`hsl()` form choice follows dart's rules** in both styles
  (0.19.0).
- **A calc writes `+ -n` as `- n` in compressed output too** (0.17.0).
- **A `round()` that cannot be folded is a calculation**, so compressed output
  drops the space after its commas (0.19.0).
- `@import` modifiers are written verbatim, a newline in a complex selector puts
  the next one on its own line, and compressed `[a="x y" i]` drops the space
  before `i` (0.19.0, 0.19.3).

### Changed (diagnostics)

- **New warning: `bogus-combinators`** (0.17.0), when a rule whose selector has
  a repeated or leading combinator (`a > + b`) is dropped. sasso already dropped
  those rules, as dart does, but said nothing; the warning is the only sign that
  the CSS lost them. Use `silence_deprecations: [:"bogus-combinators"]` to
  silence it.
- **New deprecation: `color-module-compat`** (0.19.0), e.g. for
  `color.grayscale(1)`.
- **CSS filter functions no longer raise `global-builtin`**: for example,
  `filter: grayscale(1)` (0.18.0).
- **Messages follow dart's wording** for a removed `sass:color` member, a type
  error, which now names the parameter (`$number: (1 2) is not a number.`), and
  a missing attribute operator (0.19.0, 0.19.3).
- **A stack frame names a path relative to the working directory**, not a
  `file://` URL (0.19.0).

### Changed (build)

- **The extension depends on the core with `default-features = false`.** Core
  0.19.0 added a default-on `cli-clock` feature that pulls `chrono` into Windows
  builds for the CLI's `--watch` timestamp. The library never uses it, so the
  native extension keeps its zero-dependency build.

### Performance

The library compile path is faster in every core release in this range, with
byte-identical output in the releases that only make it faster (0.20.0, 0.21.0).
Measured as instruction counts on the core's real-world corpus, 0.20.0 alone cut
vuetify by 24%, bulma by 21% and bootstrap by 8%. 0.21.0 cut uswds by 41%, by
speeding up variables reached through `@use … as *`.

## [0.14.1] - 2026-10-30

_A gem-only patch. The bundled core compiler is still `sasso` 0.14.0, so
`Sasso::CORE_VERSION` reports 0.14.0 and the CSS output is unchanged._

### Added

- **Ruby 4.0 support.** The precompiled platform gems now carry a Ruby 4.0
  binary, and CI tests against 4.0. Previously 4.0 fell back to the source gem,
  which did not compile.

### Fixed

- **The source gem compiles on Ruby 4.0.** The extension now builds against
  magnus 0.8 instead of 0.7, whose bindings do not match the Ruby 4.0 headers.

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
diffs. Every change below is **serialization only** — the CSS still means what
it meant — with **one exception, the first**: `whiteness()` / `blackness()` stop
being evaluated, which makes the declaration around them invalid, so a browser
drops it. That one is worth grepping for; the rest are safe to re-baseline.

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
