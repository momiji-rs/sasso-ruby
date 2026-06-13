# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("sasso.gemspec")

# First arg MUST equal the crate `[lib] name = "sasso"`.
RbSys::ExtensionTask.new("sasso", GEMSPEC) do |ext|
  ext.lib_dir = "lib/sasso"
end

Rake::TestTask.new(test: :compile) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: %i[compile test]
