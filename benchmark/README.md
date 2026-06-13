# Benchmark

Reproduces the numbers in the [main README](../README.md#performance):
`sasso` vs `sass-embedded` (dart-sass) vs `sassc` (libsass).

```sh
cd benchmark
bundle install
bundle exec ruby compare.rb
```

It reports, for the same SCSS (no deprecated features, so all three do equal
work):

- **WARM** — steady-state per-compile latency. `sass-embedded` keeps a persistent
  Dart subprocess after the first call, so this measures its per-call IPC
  roundtrip, not spawn cost.
- **COLD** — `require` + first compile in a fresh process (the Dart-subprocess
  spawn an out-of-process compiler pays on every one-shot build).

It also asserts `sasso`'s output is byte-identical to `sass-embedded`.

Numbers are machine-dependent — run it on your own hardware and stylesheets.
This directory is not packaged into the published gem.
