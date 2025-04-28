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

Foobara::GlobalDomain.foobara_register_type(:language, :string, one_of: %w[English Spanish])

class AnalyzedVerb < Foobara::Model
  attributes do
    verb :string, :required, "the original, uninflected verb"
    language :language, :required, "the language of the verb"
    uninflected :string, :required, "the uninflected form of the verb"
    subject :string, :allow_nil, "the noun that is the subject of the verb if there is one"
    direct_object :string, :allow_nil, "the noun that is the direct object of the verb if there is one"
    indirect_object :string, :allow_nil, "the noun that is the indirect object of the verb if there is one"
  end
end

class AnalyzedNoun < Foobara::Model
  attributes do
    noun :string, :required, "the original, uninflected noun"
    language :language, :required, "the language of the noun"
    uninflected :string, :required, "the uninflected form of the noun"
  end
end

class AnalyzedSentence < Foobara::Model
  attributes do
    original_sentence :string, :required
    language :language, :required
    corrected_sentence :string, :allow_nil,
                       "If the sentence has spelling errors, this will be a corrected version of the string"
    verbs [AnalyzedVerb], :required, default: []
    nouns [AnalyzedNoun], :required, default: []
  end
end

class ExtractVerbs < Foobara::LlmBackedCommand
  description "Accepts a sentence and extracts all of the verbs and spelling-corrects and analyzes them"

  inputs do
    sentence :string, :required, "The sentence to extract and analyze verbs from"
    llm_model Foobara::Ai::AnswerBot::Types.model_enum, default: "claude-3-7-sonnet-20250219"
  end

  result AnalyzedSentence
end

llm_model = "claude-3-7-sonnet-20250219"
# llm_model = "gpt-3.5-turbo"
# llm_model = "deepseek-r1:32b"

sentence = "The author of this script wantts to show you these commands"

analyzed_sentence = ExtractVerbs.run!(llm_model:, sentence:)

puts analyzed_sentence.original_sentence
puts analyzed_sentence.corrected_sentence
