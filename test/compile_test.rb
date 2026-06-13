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
end
