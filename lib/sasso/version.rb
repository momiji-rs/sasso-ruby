# frozen_string_literal: true

module Sasso
  # Tracks the core `sasso` crate this gem bundles: a release adopting core
  # X.Y.Z is gem X.Y.Z, and the native extension pins that crate exactly
  # (ext/sasso/Cargo.toml). A gem-only fix takes the next patch, so the gem may
  # sit ahead of the crate within a minor — `Sasso::CORE_VERSION` reads the
  # version out of the linked binary and is the authority on what is loaded.
  VERSION = "0.14.0"
end
