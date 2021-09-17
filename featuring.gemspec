# frozen_string_literal: true

require File.expand_path("../lib/featuring/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name = "featuring"
  spec.version = Featuring::VERSION
  spec.summary = "Feature flags for Ruby objects."
  spec.description = spec.summary

  spec.author = "Bryan Powell"
  spec.email = "bryan@metabahn.com"
  spec.homepage = "https://github.com/metabahn/featuring/"

  spec.required_ruby_version = ">= 2.6.7"

  spec.license = "MIT"

  spec.files = Dir["CHANGELOG.md", "README.md", "LICENSE", "lib/**/*"]
  spec.require_path = "lib"
end
