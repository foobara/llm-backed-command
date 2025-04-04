#!/usr/bin/env ruby

require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/llm_backed_command"

class DetermineLanguage < Foobara::LlmBackedCommand
  inputs code_snippet: :string
  result most_likely: :symbol, probabilities: { ruby: :float, c: :float, smalltalk: :float, java: :float }
end

puts DetermineLanguage.run!(code_snippet: "puts 'Hello, World'")
