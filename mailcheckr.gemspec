# frozen_string_literal: true

require_relative "lib/mailcheckr/version"

Gem::Specification.new do |spec|
  spec.name = "mailcheckr"
  spec.version = Mailcheckr::VERSION
  spec.summary = "Ruby client for the MailCheckr API"
  spec.description = "A Ruby SDK for creating and retrieving MailCheckr verifications."
  spec.authors = ["Kolawole Ezekiel", "Ridwan Kasim"]
  spec.email = ["doneazy911@gmail.com", "kasimsheyi20@gmail.com"]
  spec.homepage = "https://mailcheckr.app/docs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Eazybright/mailcheckr"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.files = Dir.glob("{bin,lib,spec}/**/*") + %w[Gemfile Rakefile README.md]
  spec.require_paths = ["lib"]
end
