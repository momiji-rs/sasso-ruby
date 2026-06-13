# sasso (Ruby)

In-process **SCSS / Sass → CSS** compilation for Ruby, backed by
[**sasso**](https://github.com/momiji-rs/sasso) — a pure-Rust, dependency-free
dart-sass alternative that targets **byte-for-byte parity** with current
dart-sass. Shipped as a native extension (Rust via [magnus](https://github.com/matsadler/magnus)
+ [rb-sys](https://github.com/oxidize-rb/rb-sys)); no Node, no subprocess, no
Dart VM.

> This gem is the Ruby binding. The compiler core lives in the separate
> [`momiji-rs/sasso`](https://github.com/momiji-rs/sasso) repo (crate on
> crates.io); this gem pins it exactly and releases on its own cadence.

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
Ruby 3.4.1:

| | `sasso` (this gem) | `sass-embedded` (dart-sass) | `sassc` (libsass) |
| --- | --: | --: | --: |
| Warm — small component (256 B) | **13.5 µs** | 129 µs (**9.5×**) | 1151 µs (85×) |
| Warm — ~180 rules (5.5 KB) | **237 µs** | 915 µs (**3.8×**) | 10178 µs (43×) |
| Cold start (`require` + first compile) | **1.1 ms** | 38.5 ms (**35×**) | 35.6 ms (32×) |

Parenthesised values are how much slower the other gem is than `sasso`.

- **Per-request compiling** (e.g. a Sinatra route): in-process latency is ~13 µs
  vs ~129 µs for `sass-embedded`'s pipe roundtrip to its Dart subprocess.
- **One-shot builds** (e.g. `rails assets:precompile`): the dominant cost is the
  ~38 ms Dart subprocess spawn, which `sasso` does not pay (~1 ms cold).

The engine is also heavily perf-tuned (a scoped bump arena, reference-counted
values). Numbers are representative of one machine; run your own with your
stylesheets.

## License

MIT, matching the Sass ecosystem (the core `sasso` compiler crate remains
dual-licensed MIT OR Apache-2.0).
