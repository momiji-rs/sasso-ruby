# frozen_string_literal: true

# Reproducible comparison of `sasso` vs the standard Ruby Sass gems, backing the
# Performance section of the README.
#
#   cd benchmark && bundle install && bundle exec ruby compare.rb
#
# Measures, for the same SCSS:
#   * WARM — steady-state per-compile latency (sass-embedded keeps a persistent
#     Dart subprocess after the first call, so this is its per-call IPC cost).
#   * COLD — `require` + first compile in a FRESH process (the Dart-subprocess
#     spawn that out-of-process compilers pay on every one-shot build).
#
# Numbers are machine-dependent; run it on your own hardware/stylesheets.

T0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
require "shellwords"
require_relative "inputs"

# Lazily require the engine and return a ->(scss) { css_string } lambda.
def load_engine(name)
  case name
  when "sasso"
    require "sasso"
    ->(scss) { Sasso.compile_string(scss, style: :compressed) }
  when "sass-embedded"
    require "sass-embedded"
    ->(scss) { Sass.compile_string(scss, style: :compressed).css }
  when "sassc"
    require "sassc"
    ->(scss) { SassC::Engine.new(scss, style: :compressed).render }
  else
    abort "unknown engine: #{name}"
  end
end

ENGINES = ["sasso", "sass-embedded", "sassc"].freeze

# --- COLD sub-mode: measure `require + first compile` in this fresh process. ---
if ARGV.first == "--cold"
  fn = load_engine(ARGV[1])
  fn.call(SMALL)
  printf "%.3f\n", (Process.clock_gettime(Process::CLOCK_MONOTONIC) - T0) * 1000
  exit
end

require "benchmark"

fns = ENGINES.to_h { |name| [name, load_engine(name)] }

def warm(label, scss, n, fns)
  puts "\n== WARM: #{label} (#{scss.bytesize} B, n=#{n}) =="
  base = nil
  fns.each do |name, fn|
    5.times { fn.call(scss) } # warm up
    t = Benchmark.realtime { n.times { fn.call(scss) } }
    per = t / n
    base ||= per
    printf "  %-15s %9.1f µs/op  %9.0f ops/s  %s\n",
           name, per * 1e6, n / t, (name == "sasso" ? "" : format("(%.1fx slower)", per / base))
  end
end

# Correctness: sasso must match sass-embedded (dart-sass) byte-for-byte.
ok = fns["sasso"].call(SMALL) == fns["sass-embedded"].call(SMALL)
puts "sasso output == sass-embedded (dart-sass): #{ok}"

warm("small component", SMALL, 2000, fns)
warm("~180 rules", MEDIUM, 500, fns)

puts "\n== COLD: require + first compile (fresh process, min of 3) =="
script = File.expand_path(__FILE__)
ENGINES.each do |name|
  best = 3.times.map do
    `ruby #{script.shellescape} --cold #{name}`.to_f rescue Float::INFINITY
  end.min
  printf "  %-15s %9.1f ms\n", name, best
end
