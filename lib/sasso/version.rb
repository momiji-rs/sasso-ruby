# frozen_string_literal: true

module Sasso
  # The gem version floats INDEPENDENTLY of the core `sasso` crate version; the
  # native extension pins the crate exactly (ext/sasso/Cargo.toml: sasso = "=…").
  VERSION = "0.2.0"
end
