# sasso (Ruby)

[![Gem Version](https://badge.fury.io/rb/sasso.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/sasso)

In-process **SCSS / Sass → CSS** compilation for Ruby, backed by [**sasso**](https://github.com/momiji-rs/sasso) — a pure-Rust, dependency-free dart-sass alternative that targets **byte-for-byte parity** with current dart-sass. Shipped as a native extension (Rust via [magnus](https://github.com/matsadler/magnus) + [rb-sys](https://github.com/oxidize-rb/rb-sys)); no Node, no subprocess, no Dart VM.

> This gem is the Ruby binding. The compiler core lives in the separate
> [`momiji-rs/sasso`](https://github.com/momiji-rs/sasso) repo (crate on
> crates.io); this gem pins it exactly and carries its version number.

## Install

```ruby
# Gemfile
gem "sasso"
```

```console
$ bundle install
```

Precompiled native gems ship for common platforms (Linux gnu/musl, macOS, and
Windows on x86_64/arm64), so no Rust toolchain is needed. On other platforms the
gem compiles from source via `cargo` (needs a Rust toolchain).

## Usage

```ruby
require "sasso"

Sasso.compile_string("$c: #336699; a { color: $c; &:hover { color: red } }")
# => "a {\n  color: #336699;\n}\na:hover {\n  color: red;\n}\n"

# Minified:
Sasso.compile_string("a { b: 1px }", style: :compressed)   # => "a{b:1px}"

# Indented .sass syntax:
Sasso.compile_string("a\n  b: 1px\n", indented: true)

# A file (syntax inferred from the extension; diagnostics get the file name):
Sasso.compile("app/assets/stylesheets/application.scss",
              style: :compressed, load_paths: ["vendor/stylesheets"])
```

### Options (`compile_string` / `compile`)

| Option | Default | Meaning |
| --- | --- | --- |
| `style:` | `:expanded` | `:expanded` or `:compressed` |
| `syntax:` | `:scss` | `:scss`, `:sass`, or `:css` |
| `indented:` | `false` | shorthand for `syntax: :sass` |
| `load_paths:` | `[]` | directories searched for `@use`/`@forward`/`@import` |
| `url:` | `nil` | filename shown in diagnostics (enables the rich dart-style error block) |
| `alert_ascii:` | `false` | ASCII-only diagnostics |
| `charset:` | `true` | prefix non-ASCII output with `@charset "UTF-8";` (a BOM when compressed) |
| `source_map:` | `false` | return a `Sasso::CompileResult` instead of a String |
| `source_map_include_sources:` | `false` | embed each source's text in the map's `sourcesContent` |
| `quiet:` | `false` | print no `@warn`/`@debug`/deprecation diagnostics |
| `quiet_deps:` | `false` | drop deprecation warnings raised inside dependencies |
| `on_warn:` | `nil` | a callable receiving each diagnostic; replaces the stderr printing |

### Source maps

With `source_map: true` the return value is a `Sasso::CompileResult` — `#css` is
the same String you would get otherwise, and `#source_map` is a parsed Source Map
v3 Hash. Pass `url:` so the map can name the entry stylesheet.

```ruby
r = Sasso.compile_string(scss, source_map: true, url: "application.scss")
r.css                     # => "a {\n  color: red;\n}"
r.source_map["version"]   # => 3
r.source_map["sources"]   # => ["application.scss"]
```

### Diagnostics

`@warn`, `@debug` and deprecation warnings print to `$stderr` by default, the
same dart-style block the `sasso` CLI and dart-sass print. Two ways to change
that:

```ruby
# Silence them entirely:
Sasso.compile_string(scss, quiet: true)

# Silence only what dependencies deprecate (dart-sass `quietDeps`) — files
# resolved through a load path. The entry stylesheet's own still print.
Sasso.compile_string(scss, load_paths: ["vendor/stylesheets"], quiet_deps: true)

# Or take delivery yourself, which suppresses the printing:
Sasso.compile_string(scss, url: "in.scss", on_warn: ->(d) {
  next if d[:deprecation_id] == "color-functions"

  Rails.logger.warn(d[:formatted])   # the block the compiler would have printed
})
```

A compile that warns and then fails delivers its warnings to `on_warn:` first and
raises `Sasso::CompileError` after, so the callable — the only thing printing them
at that point — never loses one.

Each diagnostic is a Hash of `Sasso::WARNING_KEYS`: `:kind` (`:warn`/`:debug`),
`:deprecation`, `:deprecation_id`, `:message`, `:formatted`, `:url`, `:line` and
`:path`. `:url` is dart's display form of the file; `:path` identifies it (the
importer's canonical path), which is what distinguishes a dependency from the
entry stylesheet. `quiet:` and `on_warn:` are mutually exclusive.

### Versions

Since 0.14.0 the gem version tracks the core compiler crate it bundles: gem
0.14.0 pins crate 0.14.0. A gem-only fix takes the next patch, so `Sasso::VERSION`
may sit ahead of the crate within a minor — `Sasso::CORE_VERSION` reads the
version out of the linked binary and is the authority on what is loaded.

```ruby
Sasso::VERSION       # => "0.14.0"  the gem
Sasso::CORE_VERSION  # => "0.14.0"  the compiler actually linked in
```

### Errors

A compile failure raises `Sasso::CompileError` (a `Sasso::Error < StandardError`)
whose `#message` is the compiler's full diagnostic — the same text the `sasso`
CLI prints.

```ruby
begin
  Sasso.compile_string("a { b: 1px + 1em }")
rescue Sasso::CompileError => e
  warn e.message
end
```

## Framework integrations

Using a Ruby web framework? These drop-in gems build on this one and compile
your Sass/SCSS **in-process** (no Node, no Dart, no subprocess), byte-for-byte
identical to dart-sass — typically ~6–7× faster per compile than the Node `sass`
default:

- **Rails** (Propshaft + Sprockets) — [`sasso-rails`](https://github.com/momiji-rs/sasso-rails)
- **Bridgetown** — [`bridgetown-sasso`](https://github.com/momiji-rs/bridgetown-sasso)
- **Hanami** (2.1+) — [`hanami-sasso`](https://github.com/momiji-rs/hanami-sasso)

## Conformance

The core passes **100% of the *attempted* official sass-spec suite**
byte-for-byte against dart-sass; see the
[core repo](https://github.com/momiji-rs/sasso#conformance). For the inputs
below, `sasso`'s output is **byte-identical to `sass-embedded`** (dart-sass).

## Performance

Because `sasso` compiles **in-process** (a direct Rust call — no subprocess, no
IPC, no Dart VM), it avoids the per-call protocol roundtrip of `sass-embedded`
and the process-spawn cost paid by any out-of-process compiler.

Compiling the same SCSS (variables, nesting, `@for`, math) on an Apple M2 Max,
Ruby 3.4.1, against `sass-embedded` 1.104.1 and `sassc` 2.4.0:

| | `sasso` (this gem) | `sass-embedded` (dart-sass) | `sassc` (libsass) |
| --- | --: | --: | --: |
| Warm — small component (256 B) | **13.3 µs** | 125 µs (**9.4×**) | 1148 µs (87×) |
| Warm — ~180 rules (5.5 KB) | **215 µs** | 906 µs (**4.2×**) | 10234 µs (48×) |
| Cold start (`require` + first compile) | **3.2 ms** | 40.6 ms (**12.7×**) | 37.0 ms (12×) |

Parenthesised values are how much slower the other gem is than `sasso`.

- **Per-request compiling** (e.g. a Sinatra route): in-process latency is ~13 µs
  vs ~125 µs for `sass-embedded`'s pipe roundtrip to its Dart subprocess.
- **One-shot builds** (e.g. `rails assets:precompile`): the dominant cost is the
  ~41 ms Dart subprocess spawn, which `sasso` does not pay (~3 ms cold).

The engine is also heavily perf-tuned (a scoped bump arena, reference-counted
values). Numbers are representative of one machine; run your own with your
stylesheets.

## License

MIT, matching the Sass ecosystem (the core `sasso` compiler crate remains
dual-licensed MIT OR Apache-2.0).
