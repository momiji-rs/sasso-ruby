# frozen_string_literal: true

require_relative "lib/sasso/version"

Gem::Specification.new do |spec|
  spec.name        = "sasso"
  spec.version     = Sasso::VERSION
  spec.authors     = ["momiji-rs"]
  spec.summary     = "Pure-Rust SCSS to CSS compiler (a dart-sass alternative), in-process via a native extension."
  spec.description = "Embeddable, dependency-free SCSS/Sass compiler aiming at byte-for-byte dart-sass parity, " \
                     "shipped as a Rust native extension (magnus + rb-sys)."
  spec.homepage    = "https://github.com/momiji-rs/sasso-ruby"
  spec.license     = "MIT"

  spec.required_ruby_version     = ">= 3.1.0"
  spec.required_rubygems_version = ">= 3.3.22" # clean precompiled-platform resolution

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
  }

  # The cargo crate (Cargo.toml/lock + ext/) must be packaged so the source-gem
  # install path can compile via extconf.rb on platforms without a prebuilt gem.
  spec.files = Dir[
    "lib/**/*.rb",
    "ext/**/*.{rs,rb}",
    "ext/**/Cargo.toml",
    "Cargo.toml", "Cargo.lock",
    "sig/**/*.rbs",
    "LICENSE-MIT", "README.md", "CHANGELOG.md",
  ]
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/sasso/extconf.rb"]

  # rb_sys is the only runtime-listed dep, and only exercised on the
  # compile-from-source path; precompiled platform gems ship the prebuilt
  # binary and never load it. (magnus / the core `sasso` crate are cargo-side.)
  spec.add_dependency "rb_sys", "~> 0.9.111"

  spec.add_development_dependency "rake",          "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2"
  spec.add_development_dependency "minitest",      "~> 5.0"
end
