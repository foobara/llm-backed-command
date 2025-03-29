#!/usr/bin/env ruby

require "foobara/load_dotenv"

Foobara::LoadDotenv.run!(env: "development", dir: __dir__)

require "foobara/anthropic_api"
require "foobara/open_ai_api"
require "foobara/ollama_api"

require "foobara/llm_backed_command"

class PossibleUsState < Foobara::Model
  attributes do
    name :string, :required,
         "A name that potentially might be a name of a US state, spelled correctly or incorrectly"
  end
end

class VerifiedUsState < Foobara::Model
  attributes do
    possible_us_state PossibleUsState, :required,
                      "The original possible US state that was passed in"
    spelling_correction_required :boolean, :required, "Whether or not the original spelling was correct"
    corrected_spelling :string, :allow_nil,
                       "If the original spelling was incorrect, the corrected spelling will be here"
  end
end

class SelectedAndCorrectedUsStateNames < Foobara::Model
  attributes verified: [VerifiedUsState], rejected: [PossibleUsState]
end

class SelectUsStateNamesAndCorrectTheirSpelling < Foobara::LlmBackedCommand
  description <<~DESCRIPTION
    Accepts a list of possible US state names and sorts them into verified to be the name of a
    US state and rejected to be the name of a non-US state, as well as correcting the spelling of
    the US state name if it's not correct.

    example:

    If you pass in ["Kalifornia", "Los Angeles", "New York"] the result will be:

    result.verified.length # => 2
    result.verified[0].possible_us_state.name # => "Kalifornia"
    result.verified[0].spelling_correction_required # => true#{" "}
    result.verified[0].corrected_spelling # => "California"
    result.verified[1].possible_us_state.name # => "New York"
    result.verified[1].spelling_correction_required # => false
    result.verified[1].corrected_spelling # => nil

    result.rejected.length # => 1
    result.rejected[0].name # => "Los Angeles"
  DESCRIPTION

  inputs do
    list_of_possible_us_states [PossibleUsState], :required
    llm_model Foobara::Ai::AnswerBot::Types.model_enum, default: "claude-3-7-sonnet-20250219"
  end

  result SelectedAndCorrectedUsStateNames
end

list_of_possible_us_states = [
  PossibleUsState.new(name: "Grand Rapids"),
  PossibleUsState.new(name: "Oregon"),
  PossibleUsState.new(name: "Yutah"),
  PossibleUsState.new(name: "Misisipi"),
  PossibleUsState.new(name: "Tacoma"),
  PossibleUsState.new(name: "Kalifornia"),
  PossibleUsState.new(name: "Los Angeles"),
  PossibleUsState.new(name: "New York")
]
# llm_model = "gpt-3.5-turbo"

puts "Considering:"
list_of_possible_us_states.each do |possible_us_state|
  puts "  #{possible_us_state.name}"
end
puts

result = SelectUsStateNamesAndCorrectTheirSpelling.run!(list_of_possible_us_states:)

puts "#{result.verified.length} were verified as US states:"
result.verified.each do |verified_us_state|
  puts "  #{verified_us_state.corrected_spelling || verified_us_state.possible_us_state.name}"
  if verified_us_state.spelling_correction_required
    puts "    original incorrect spelling: #{verified_us_state.possible_us_state.name}"
  end
end

puts
puts "#{result.rejected.length} were rejected as non-US states:"
result.rejected.each do |rejected_us_state|
  puts "  #{rejected_us_state.name}"
end
