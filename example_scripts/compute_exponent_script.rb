#!/usr/bin/env ruby

require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(env: "development", dir: __dir__)

require "foobara/anthropic_api"
require "foobara/open_ai_api"
require "foobara/ollama_api"
require "foobara/llm_backed_command"

module Math
  class ComputeExponent < Foobara::LlmBackedCommand
    inputs base: :integer, exponent: :integer, llm_model: Foobara::Ai::AnswerBot::Types.model_enum
    result :integer
  end
end

llm_model = "claude-3-7-sonnet-20250219"
# llm_model = "gpt-3.5-turbo"
# llm_model = "deepseek-r1:32b"

base = 2
exponent = 4

command = Math::ComputeExponent.new(base:, exponent:, llm_model:)
outcome = command.run

if outcome.success?
  puts outcome.result
else
  puts outcome.errors_hash
end
