# frozen_string_literal: true

require "json"
require_relative "sasso/version"

module Sasso
  # Base error for the gem.
  class Error < StandardError; end

  # Raised on a Sass compile failure. `#message` is the compiler's full
  # diagnostic (the same text the `sasso` CLI prints) when a `url:` is given,
  # otherwise the legacy `Error: <msg> (line:col)` one-liner.
  class CompileError < Error; end

  # Returned by `compile_string`/`compile` when `source_map: true`. `#css` is the
  # CSS String (identical to the plain-String return); `#source_map` is the
  # Source Map v3 as a parsed Hash (`"version" => 3`, `"mappings"`, `"sources"`, …).
  CompileResult = Struct.new(:css, :source_map)
end

# Load the compiled native extension. Precompiled ("fat") gems place a copy per
# Ruby minor under lib/sasso/<major.minor>/; a source build (rake compile /
# `gem install` fallback) places it flat at lib/sasso/sasso.{so,bundle}. The
# `Sasso::CompileError` class above is defined BEFORE this require so the native
# code can raise it.
begin
  RUBY_VERSION =~ /(\d+\.\d+)/
  require_relative "sasso/#{Regexp.last_match(1)}/sasso"
rescue LoadError
  require_relative "sasso/sasso"
end

module Sasso
  STYLES   = %i[expanded compressed].freeze
  SYNTAXES = %i[scss sass css].freeze

  module_function

  # Compile a SCSS/Sass source String to a CSS String.
  #
  #   style:       :expanded (default) | :compressed
  #   syntax:      :scss (default) | :sass | :css
  #   indented:    true => shorthand for syntax: :sass
  #   load_paths:  dirs searched for @use/@forward/@import (built-in importer)
  #   url:         filename shown in diagnostics; ENABLES the dart-exact error block
  #   alert_ascii: true => ASCII-only diagnostics (maps to the compiler's no-unicode)
  #
  # Raises Sasso::CompileError on a compile failure; ArgumentError on bad options.
  def compile_string(source, style: :expanded, syntax: :scss, indented: false,
                     load_paths: [], url: nil, alert_ascii: false,
                     source_map: false, source_map_include_sources: false)
    syntax = :sass if indented
    validate!(style, STYLES, :style)
    validate!(syntax, SYNTAXES, :syntax)
    # A positional Hash, not keyword arguments: `_compile` is a C function and
    # has no keyword parameters, so the braces say what actually crosses the ABI.
    css, map_json = Sasso::Native._compile(String(source), {
                                             style: style.to_s,
                                             syntax: syntax.to_s,
                                             load_paths: Array(load_paths).map(&:to_s),
                                             url: url && url.to_s,
                                             unicode: !alert_ascii,
                                             source_map: source_map,
                                             source_map_include_sources: source_map_include_sources,
                                           })
    return css unless source_map

    CompileResult.new(css, JSON.parse(map_json))
  end

  # Compile the file at `path`. Syntax is inferred from the extension unless
  # overridden; `url:` defaults to `path` so diagnostics get the dart-exact block.
  #
  # The entry file's own directory is searched FIRST for relative @use/@forward/
  # @import (the `sass` CLI convention — a file on disk can always import its
  # siblings), ahead of any caller-supplied `load_paths:`.
  def compile(path, **opts)
    src = File.read(path)
    inferred =
      case File.extname(path)
      when ".sass" then :sass
      when ".css"  then :css
      else :scss
      end
    given = Array(opts.delete(:load_paths)).map(&:to_s)
    load_paths = [File.dirname(path.to_s), *given]
    compile_string(src, syntax: inferred, url: path.to_s, load_paths: load_paths, **opts)
  end

  def validate!(value, allowed, name)
    return if allowed.include?(value)

    raise ArgumentError,
          "invalid #{name}: #{value.inspect} (expected one of #{allowed.inspect})"
  end
  private_class_method :validate!
end
