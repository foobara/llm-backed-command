require_relative "version"

Gem::Specification.new do |spec|
  spec.name = "foobara-llm-backed-command"
  spec.version = Foobara::LlmBackedCommandVersion::VERSION
  spec.authors = ["Miles Georgi"]
  spec.email = ["azimux@gmail.com"]

  spec.summary = "Provides an easy way to implement a command whose logic is managed by an LLM"
  spec.homepage = "https://github.com/foobara/llm-backed-command"
  spec.license = "MPL-2.0"
  spec.required_ruby_version = Foobara::LlmBackedCommandVersion::MINIMUM_RUBY_VERSION

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "src/**/*",
    "LICENSE*.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.add_dependency "foobara", "~> 0.0.92"
  spec.add_dependency "foobara-ai", "~> 0.0.1"
  spec.add_dependency "foobara-json-schema-generator", "~> 0.0.1"

  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
