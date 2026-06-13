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
end
