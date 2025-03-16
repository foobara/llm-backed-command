#!/usr/bin/env ruby

require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/llm_backed_command"

class PossibleUsState < Foobara::Model
  attributes name: :string
end

class VerifiedUsState < Foobara::Model
  attributes possible_us_state: PossibleUsState, corrected_spelling: :string, spelling_correction_required: :boolean
end

class SelectedAndCorrectedUsStateNames < Foobara::Model
  attributes verified: [VerifiedUsState], rejected: [PossibleUsState]
end

class SelectUsStateNamesAndCorrectTheirSpelling < Foobara::LlmBackedCommand
  inputs list_of_possible_us_states: [PossibleUsState]
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

puts "Considering:"
list_of_possible_us_states.each do |possible_us_state|
  puts "  #{possible_us_state.name}"
end

result = SelectUsStateNamesAndCorrectTheirSpelling.run!(list_of_possible_us_states:)

puts "\n#{result.verified.length} were verified as US states:"
result.verified.each do |verified_us_state|
  puts "  #{verified_us_state.corrected_spelling || verified_us_state.possible_us_state.name}"
  if verified_us_state.spelling_correction_required
    puts "    original incorrect spelling: #{verified_us_state.possible_us_state.name}"
  end
end

puts "\n#{result.rejected.length} were rejected as non-US states:"
result.rejected.each do |rejected_us_state|
  puts "  #{rejected_us_state.name}"
end
