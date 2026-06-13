# frozen_string_literal: true

# Shared benchmark inputs — feature-equivalent across all three engines
# (variables, nesting, @for, integer math). Deliberately NO deprecated features
# (no division, no darken/lighten), so sass-embedded emits zero deprecation I/O
# and the comparison is about raw compile speed, not warning overhead.

SMALL = <<~SCSS
  $brand: #3366cc;
  $pad: 8px;
  .btn {
    color: $brand;
    padding: $pad ($pad * 2);
    border: 1px solid $brand;
    font-weight: bold;
    &:hover { background: $brand; color: #fff; }
    &.large { padding: ($pad * 2) ($pad * 4); }
    .icon { margin-right: $pad; }
  }
SCSS

MEDIUM = (+"$base: 4px;\n").tap do |s|
  (1..60).each do |i|
    s << ".m-#{i} { margin: $base * #{i}; }\n"
    s << ".p-#{i} { padding: $base * #{i}; }\n"
    s << ".gap-#{i} { gap: $base * #{i}; }\n"
  end
  s << <<~SCSS
    .card {
      border: 1px solid #ccc;
      .title { font-size: 18px; .sub { color: #666; } }
      .body { padding: 16px; p { margin: 0 0 8px; } }
    }
  SCSS
end
