# frozen_string_literal: true
require "mkmf"
require "rb_sys/mkmf"

# Arg MUST equal the crate `[lib] name` + the ExtensionTask name, so the built
# artifact lands at lib/sasso/sasso.{so,bundle} -> `require "sasso/sasso"`.
create_rust_makefile("sasso/sasso")
