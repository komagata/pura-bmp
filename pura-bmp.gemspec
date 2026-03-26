# frozen_string_literal: true

require_relative "lib/pura/bmp/version"

Gem::Specification.new do |spec|
  spec.name = "pura-bmp"
  spec.version = Pura::Bmp::VERSION
  spec.authors = ["komagata"]
  spec.summary = "Pure Ruby BMP decoder/encoder"
  spec.description = "A pure Ruby BMP decoder and encoder with zero C extension dependencies. " \
                     "Supports 1/4/8/24/32-bit color depths, RLE8 compression, and both bottom-up and top-down storage."
  spec.homepage = "https://github.com/komagata/pure-bmp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["pura-bmp"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
