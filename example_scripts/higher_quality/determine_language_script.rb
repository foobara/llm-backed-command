#!/usr/bin/env ruby

# ENV["ANTHROPIC_API_KEY"] = "<your key here>"
# ENV["OPENAI_API_KEY"] = "<your key here>"
# ENV["OLLAMA_API_URL"] = "<your url here>"

# if using .env like this instead of setting ENV then run `gem install foobara-dotenv-loader`
require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/anthropic_api"
require "foobara/open_ai_api"
require "foobara/ollama_api"

require "foobara/llm_backed_command"

class DetermineLanguage < Foobara::LlmBackedCommand
  description "Accepts a code snippet and returns which language it is most likely to be."

  inputs do
    code_snippet :string, :required, "The code snippet you'd like to determine the language of"
    llm_model Foobara::Ai::AnswerBot::Types.model_enum, default: "claude-3-7-sonnet-20250219"
  end

  result do
    most_likely :symbol, :required, one_of: %w[ruby c smalltalk java]
    probabilities description: "Estimated probabilities of each language between 0 and 1" do
      ruby :float, :required
      c :float, :required
      smalltalk :float, :required
      java :float, :required
    end
  end
end

llm_model = "claude-3-7-sonnet-20250219"
# llm_model = "gpt-3.5-turbo"
# llm_model = "deepseek-r1:32b"

code_snippet = "puts 'Hello, World'"

puts DetermineLanguage.run!(llm_model:, code_snippet:)
