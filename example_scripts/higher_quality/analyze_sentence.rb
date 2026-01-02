#!/usr/bin/env ruby

require "bundler/setup"

# add your keys/urls to .env or set them some other way and delete these two lines
require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/anthropic_api" if ENV.key?("ANTHROPIC_API_KEY")
require "foobara/open_ai_api" if ENV.key?("OPENAI_API_KEY")
require "foobara/ollama_api" if ENV.key?("OLLAMA_API_URL")

require "foobara/llm_backed_command"

Foobara::GlobalDomain.foobara_register_type(:language, :string, one_of: ["English", "Spanish"])

class AnalyzedVerb < Foobara::Model
  attributes do
    verb :string, :required, "the original, uninflected, spell-corrected verb"
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
    english_translation :string, :allow_nil, "If the sentence is in Spanish, this will be the English translation"
    language :language, :required
    corrected_sentence :string, :allow_nil,
                       "If the sentence has spelling errors, this will be a corrected version of the string"
    verbs [AnalyzedVerb], :required, default: []
    nouns [AnalyzedNoun], :required, default: []
  end
end

class AnalyzeSentence < Foobara::LlmBackedCommand
  description "Accepts a sentence and extracts all of the verbs and spelling-corrects and analyzes them"

  inputs do
    sentence :string, :required, "The sentence to extract and analyze verbs from"
    llm_model Foobara::Ai::AnswerBot::Types.model_enum, default: "claude-3-7-sonnet-20250219"
  end

  result AnalyzedSentence
end

# require "pry"
# require "pry-byebug"

llm_model = "claude-3-7-sonnet-20250219"
# llm_model = "gpt-3.5-turbo"
# llm_model = "deepseek-r1:32b"

sentence = "El autor de este script quierre mostrarte estos comandos"

analyzed_sentence = AnalyzeSentence.run!(llm_model:, sentence:)

puts "The original sentence was:"
puts analyzed_sentence.original_sentence
puts "The spell-corrected sentence is:"
puts analyzed_sentence.corrected_sentence
puts "The English translation is:"
puts analyzed_sentence.english_translation

verb = analyzed_sentence.verbs.first

puts "The first verb class is: #{verb.class}"
puts "and its uninflected form is: #{verb.uninflected}"
