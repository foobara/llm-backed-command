#!/usr/bin/env ruby

require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/llm_backed_command"

class ComputeExponent < Foobara::LlmBackedCommand
  inputs base: :integer, exponent: :integer
  result :integer
end

puts ComputeExponent.run!(base: 2, exponent: 4)
