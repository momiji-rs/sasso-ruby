# frozen_string_literal: true

require_relative "test_helper"

class CompileTest < Minitest::Test
  def test_basic_expanded
    assert_equal "a {\n  b: 1px;\n}\n", Sasso.compile_string("a{b:1px}")
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

  def test_unit_arithmetic
    assert_equal "a {\n  w: 16px;\n}\n", Sasso.compile_string("a{w:8px * 2}")
  end

  def test_indented_syntax
    css = Sasso.compile_string("a\n  b: 1px\n", indented: true)
    assert_equal "a {\n  b: 1px;\n}\n", css
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
      assert_equal "a {\n  b: 1;\n}\n", Sasso.compile(f.path)
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
    assert_equal ".a {\n  x: 1;\n}\n.b {\n  y: 2;\n}\n\n.a {\n  z: 3;\n}\n", Sasso.compile_string(scss)
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
end
