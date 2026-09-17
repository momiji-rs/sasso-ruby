# frozen_string_literal: true

require_relative "test_helper"

class CompileTest < Minitest::Test
  def test_basic_expanded
    assert_equal "a {\n  b: 1px;\n}", Sasso.compile_string("a{b:1px}")
  end

  def test_variables_and_nesting
    css = Sasso.compile_string("$c:#333;a{color:$c;&:hover{color:red}}")
    assert_includes css, "a {"
    assert_includes css, "color: #333;"
    assert_includes css, "a:hover {"
  end

  def test_compressed
    assert_equal "a{b:1px}", Sasso.compile_string("a { b: 1px }", style: :compressed)
  end

  # Core sasso 0.6.3: the library API returns the stylesheet with NO trailing
  # newline (byte-for-byte dart-sass's library API). The CLI/asset pipelines
  # re-add one; the gem itself must not.
  def test_no_trailing_newline
    refute Sasso.compile_string("a{b:1px}").end_with?("\n"), "expanded must not end with a newline"
    refute Sasso.compile_string("a{b:1px}", style: :compressed).end_with?("\n"), "compressed must not end with a newline"
  end

  # Core sasso 0.9.0: a legacy color with any fractional channel serializes its
  # rgb triple as percentages (dart-sass 1.101.4), and compressed hsl routes
  # through rgb like every other legacy space. `darken(#336699,10%)` lands on
  # fractional channels, so it takes the percent rgb form; an integer-equivalent
  # hsl literal still collapses to hex. Both verified against dart-sass 1.104.1.
  def test_compressed_color_shortest_form
    assert_equal "a{x:rgb(15%,30%,45%)}",
                 Sasso.compile_string("a{x:darken(#336699,10%)}", style: :compressed)
    assert_equal "a{x:#369}",
                 Sasso.compile_string("a{x:hsl(210,50%,40%)}", style: :compressed)
  end

  def test_unit_arithmetic
    assert_equal "a {\n  w: 16px;\n}", Sasso.compile_string("a{w:8px * 2}")
  end

  def test_indented_syntax
    css = Sasso.compile_string("a\n  b: 1px\n", indented: true)
    assert_equal "a {\n  b: 1px;\n}", css
  end

  def test_compile_error_is_raised
    err = assert_raises(Sasso::CompileError) { Sasso.compile_string("a{b: 1px + 1em}") }
    assert_match(/incompatible units/, err.message)
  end

  def test_invalid_style_raises_argument_error
    assert_raises(ArgumentError) { Sasso.compile_string("a{b:c}", style: :nope) }
  end

  def test_compile_file
    require "tempfile"
    Tempfile.create(["t", ".scss"]) do |f|
      f.write("$x:1;a{b:$x}"); f.flush
      assert_equal "a {\n  b: 1;\n}", Sasso.compile(f.path)
    end
  end

  # A file on disk must be able to @use/@import a sibling partial without the
  # caller spelling out load_paths (the `sass` CLI convention).
  def test_compile_file_resolves_sibling_import
    require "tmpdir"
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "_tokens.scss"), "$brand: #3366cc;")
      main = File.join(dir, "main.scss")
      File.write(main, %(@use "tokens" as t;\n.btn { color: t.$brand; }\n))
      css = Sasso.compile(main)
      assert_includes css, "color: #3366cc;"
    end
  end

  # An explicit load_paths: is still honored alongside the implicit entry-file dir.
  def test_compile_file_keeps_explicit_load_paths
    require "tmpdir"
    Dir.mktmpdir do |dir|
      sub = File.join(dir, "shared")
      Dir.mkdir(sub)
      File.write(File.join(sub, "_vars.scss"), "$x: 9px;")
      main = File.join(dir, "main.scss")
      File.write(main, %(@use "vars" as v;\n.y { margin: v.$x; }\n))
      css = Sasso.compile(main, load_paths: [sub])
      assert_includes css, "margin: 9px;"
    end
  end

  # --- source maps ---

  def test_source_map_returns_compile_result_with_v3_map
    scss = ".a {\n  color: red;\n  .b { width: 10px; }\n}\n"
    r = Sasso.compile_string(scss, source_map: true, url: "in.scss")

    assert_instance_of Sasso::CompileResult, r
    # css is identical to the plain-String return
    assert_equal Sasso.compile_string(scss), r.css
    map = r.source_map
    assert_equal 3, map["version"]
    assert_equal ["in.scss"], map["sources"]
    assert_equal [], map["names"]
    refute_empty map["mappings"]
    # mappings is base64-VLQ shaped
    assert_match(%r{\A[A-Za-z0-9+/]*[;,]?(?:[A-Za-z0-9+/]*[;,]?)*\z}, map["mappings"])
    # no sourcesContent unless asked
    refute map.key?("sourcesContent")
  end

  def test_source_map_include_sources_embeds_content
    scss = ".a { color: red; }\n"
    r = Sasso.compile_string(scss, source_map: true, source_map_include_sources: true, url: "in.scss")
    assert_equal [scss], r.source_map["sourcesContent"]
  end

  def test_compile_string_without_source_map_returns_plain_string
    assert_instance_of String, Sasso.compile_string("a { b: 1px }")
  end

  # Regression guard for the core v0.5.1 bubbled-selector source-map fix: a
  # `@media` nested in a style rule maps the bubbled `.a` copy back to the
  # original selector, so the compressed map keeps all 7 segments dart-sass
  # 1.101 emits (a naive same-source-line dedup would drop two).
  def test_compressed_source_map_bubbled_media_matches_dart
    scss = ".a {\n  color: red;\n  @media screen { width: 1px; }\n  height: 2px;\n}\n"
    r = Sasso.compile_string(scss, source_map: true, style: :compressed, url: "in.scss")
    assert_equal ".a{color:red}@media screen{.a{width:1px}}.a{height:2px}", r.css
    assert_equal "AAAA,GACE,UACA,cAFF,GAEkB,WAFlB,GAGE", r.source_map["mappings"]
  end

  # Regression guard for the core v0.5.2 @at-root group-separation fix: expanded
  # output gets one blank line before the resumed parent rule (byte-exact dart).
  def test_at_root_group_separation_blank_line
    scss = ".a {\n  x: 1;\n  @at-root .b {\n    y: 2;\n  }\n  z: 3;\n}\n"
    assert_equal ".a {\n  x: 1;\n}\n.b {\n  y: 2;\n}\n\n.a {\n  z: 3;\n}", Sasso.compile_string(scss)
  end

  def test_compile_file_supports_source_map
    require "tmpdir"
    Dir.mktmpdir do |dir|
      path = File.join(dir, "main.scss")
      File.write(path, ".a { color: red; }\n")
      r = Sasso.compile(path, source_map: true)
      assert_instance_of Sasso::CompileResult, r
      assert_equal 3, r.source_map["version"]
    end
  end

  # `@warn` reaches stderr by default, as the sasso CLI and dart-sass do.
  def test_warnings_print_to_stderr_by_default
    _out, err = capture_subprocess_io do
      Sasso.compile_string(%(@warn "careful";\na{b:1}), url: "in.scss")
    end
    assert_includes err, "careful"
  end

  def test_quiet_silences_warnings
    _out, err = capture_subprocess_io do
      css = Sasso.compile_string(%(@warn "careful";\na{b:1}), url: "in.scss", quiet: true)
      assert_equal "a {\n  b: 1;\n}", css
    end
    assert_empty err
  end

  # Taking delivery through on_warn: replaces the stderr printing rather than
  # duplicating it, and each diagnostic arrives as a Hash of WARNING_KEYS.
  def test_on_warn_receives_each_diagnostic_and_suppresses_stderr
    seen = []
    _out, err = capture_subprocess_io do
      Sasso.compile_string(%(@warn "careful";\n@debug "looking";\na{b:1}),
                           url: "in.scss", on_warn: ->(d) { seen << d })
    end
    assert_empty err
    assert_equal %i[warn debug], seen.map { |d| d[:kind] }
    assert_equal ["careful", "looking"], seen.map { |d| d[:message] }
    seen.each do |d|
      assert_equal Sasso::WARNING_KEYS.sort, d.keys.sort
      assert_equal "in.scss", d[:url]
      assert_includes d[:formatted], "in.scss"
    end
    refute seen.first[:deprecation]
    assert_equal 1, seen.first[:line]
  end

  # A deprecation carries its id, which is how a caller filters one out.
  def test_on_warn_reports_deprecations_with_an_id
    seen = []
    Sasso.compile_string("a{x:darken(#336699,10%)}", url: "in.scss", on_warn: ->(d) { seen << d })
    assert(seen.any? { |d| d[:deprecation] && d[:deprecation_id] == "color-functions" },
           "expected a color-functions deprecation, got #{seen.map { |d| d[:deprecation_id] }.inspect}")
  end

  # A compile can warn and THEN fail. Under on_warn: the callable is the only
  # thing printing those warnings, so they have to survive the error — dart-sass
  # hands them to its logger before it throws too. The error still raises.
  def test_on_warn_receives_warnings_raised_before_a_compile_error
    seen = []
    err = assert_raises(Sasso::CompileError) do
      Sasso.compile_string(%(@warn "before the error";\na{b: 1px + 1em}),
                           url: "in.scss", on_warn: ->(d) { seen << d })
    end
    assert_match(/incompatible units/, err.message)
    assert_equal ["before the error"], seen.map { |d| d[:message] }
  end

  # A callable that blows up must not take the Sass error with it: the compile
  # failure is the actual news, and a logger being down is incidental to it.
  def test_a_raising_on_warn_does_not_mask_the_compile_error
    err = assert_raises(Sasso::CompileError) do
      Sasso.compile_string(%(@warn "w";\na{b: 1px + 1em}),
                           url: "in.scss", on_warn: ->(_d) { raise "logger down" })
    end
    assert_match(/incompatible units/, err.message)
    assert_equal "logger down", err.cause.message
  end

  # With no compile error to preserve, the callable's exception is the only one.
  def test_a_raising_on_warn_propagates_on_a_successful_compile
    err = assert_raises(RuntimeError) do
      Sasso.compile_string(%(@warn "w";\na{b:1}), url: "in.scss",
                                                  on_warn: ->(_d) { raise "logger down" })
    end
    assert_equal "logger down", err.message
  end

  # The compiler caps a repeated deprecation at five per id and then reports the
  # remainder as one span-less summary diagnostic, as dart-sass does. Documented
  # because it is the one diagnostic with no :deprecation_id, :url or :line.
  def test_repeated_deprecations_are_capped_and_summarized
    src = (1..12).map { |i| ".c#{i}{x:darken(#336699,10%)}" }.join("\n")
    seen = []
    Sasso.compile_string(src, url: "in.scss", on_warn: ->(d) { seen << d })
    assert_equal 5, seen.count { |d| d[:deprecation_id] == "color-functions" }
    summary = seen.last
    assert_match(/repetitive deprecation warnings omitted/, summary[:message])
    assert_equal ["", "", 0], [summary[:deprecation_id], summary[:url], summary[:line]]
  end

  def test_quiet_and_on_warn_are_mutually_exclusive
    err = assert_raises(ArgumentError) do
      Sasso.compile_string("a{b:1}", quiet: true, on_warn: ->(_d) {})
    end
    assert_match(/mutually exclusive/, err.message)
  end

  def test_on_warn_must_be_callable
    assert_raises(ArgumentError) { Sasso.compile_string("a{b:1}", on_warn: :not_callable) }
  end

  # quiet_deps: drops a dependency's deprecation warnings (dart-sass quietDeps)
  # while the entry stylesheet's own still come through, and @warn is untouched
  # either way — dart classifies by how a file was RESOLVED, so the partial has
  # to be reached through a load path to count.
  def test_quiet_deps_silences_only_a_dependency_deprecation
    require "tmpdir"
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "_dep.scss"), %(@warn "from dep";\n.d{x:darken(#336699,10%)}\n))
      entry = %(@use "dep";\n.e{y:darken(#336699,10%)}\n)

      loud = collect(entry, dir)
      assert_equal 2, loud.count { |d| d[:deprecation_id] == "color-functions" }

      quiet = collect(entry, dir, quiet_deps: true)
      assert_equal 1, quiet.count { |d| d[:deprecation_id] == "color-functions" }
      assert_includes quiet.map { |d| d[:message] }, "from dep"
    end
  end

  # Non-ASCII output carries a prefix declaring UTF-8, and charset: false drops
  # it (dart-sass `charset` / `--no-charset`). Expanded gets `@charset`, and
  # compressed a BOM — verified byte-for-byte against dart-sass 1.104.1.
  def test_charset_prefixes_non_ascii_output
    scss = %(a{content:"café"})
    assert_equal %(@charset "UTF-8";\na {\n  content: "café";\n}), Sasso.compile_string(scss)
    assert_equal %(a {\n  content: "café";\n}), Sasso.compile_string(scss, charset: false)
  end

  def test_charset_is_a_bom_when_compressed
    scss = %(a{content:"café"})
    assert_equal %(﻿a{content:"café"}), Sasso.compile_string(scss, style: :compressed)
    assert_equal %(a{content:"café"}),
                 Sasso.compile_string(scss, style: :compressed, charset: false)
  end

  # Nothing to declare when the output is all ASCII, charset: or not.
  def test_charset_is_absent_from_ascii_output
    assert_equal "a {\n  b: 1;\n}", Sasso.compile_string("a{b:1}")
    assert_equal "a {\n  b: 1;\n}", Sasso.compile_string("a{b:1}", charset: false)
  end

  # CORE_VERSION comes from the linked crate, so it doubles as a guard that the
  # binary loaded really is the version ext/sasso/Cargo.toml pins — the drift
  # the core's own `VERSION` was added to make impossible.
  def test_core_version_matches_the_pinned_crate
    manifest = File.read(File.expand_path("../ext/sasso/Cargo.toml", __dir__))
    pinned = manifest[/package = "sasso", version = "=([\d.]+)"/, 1]
    refute_nil pinned, "could not find the core crate pin in ext/sasso/Cargo.toml"
    assert_equal pinned, Sasso::CORE_VERSION
  end

  private

  def collect(source, dir, **opts)
    seen = []
    Sasso.compile_string(source, url: "in.scss", load_paths: [dir],
                                 on_warn: ->(d) { seen << d }, **opts)
    seen
  end
end
