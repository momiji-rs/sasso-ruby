# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("sasso.gemspec")

# First arg MUST equal the crate `[lib] name = "sasso"`.
RbSys::ExtensionTask.new("sasso", GEMSPEC) do |ext|
  ext.lib_dir = "lib/sasso"
  # Precompiled ("fat") binary gems, built per platform in CI via
  # oxidize-rb/actions/cross-gem (rb-sys-dock). Source-gem fallback covers the rest.
  ext.cross_compile  = true
  ext.cross_platform = %w[
    x86_64-linux aarch64-linux
    x86_64-linux-musl aarch64-linux-musl
    x86_64-darwin arm64-darwin
    x64-mingw-ucrt
  ]
end

Rake::TestTask.new(test: :compile) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: %i[compile test]
