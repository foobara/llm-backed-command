require_relative "version"

source "https://rubygems.org"
ruby Foobara::LlmBackedCommandVersion::MINIMUM_RUBY_VERSION

gemspec

# gem "foobara", path: "../foobara"
# gem "foobara-ai", path: "../ai"

gem "foobara-dotenv-loader", "~> 0.0.1"

gem "rake"

group :development do
  gem "foob"
  gem "foobara-rubocop-rules", ">= 1.0.0"
  gem "guard-rspec"
  gem "rubocop-rake"
  gem "rubocop-rspec"
end

group :development, :test do
  gem "foobara-anthropic-api", "< 2.0.0" # , path: "../anthropic-api"
  gem "foobara-ollama-api", "< 2.0.0"
  gem "foobara-open-ai-api", "< 2.0.0"
  gem "pry"
  gem "pry-byebug"
  # TODO: Just adding this to suppress warnings seemingly coming from pry-byebug. Can probably remove this once
  # pry-byebug has irb as a gem dependency
  gem "irb"
end

group :test do
  gem "foobara-spec-helpers", "~> 0.0.1"
  gem "rspec"
  gem "rspec-its"
  gem "ruby-prof"
  gem "simplecov"
  gem "vcr"
  gem "webmock"
end
