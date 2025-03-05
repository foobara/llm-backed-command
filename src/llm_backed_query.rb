# TODO: move serializers to their own project so we don't have to include command_connectors to use them
require "foobara/command_connectors"
require "foobara/ai"
require "foobara/json_schema_generator"

# NOTE: You can add the following inputs if you'd like, or, create methods with these names
# on the class.
#
# inputs do
#   association_depth :symbol, one_of: JsonSchemaGenerator::AssociationDepth, default: AssociationDepth::ATOM
#   llm_model :symbol, one_of: Foobara::Ai::AnswerBot::Types::ModelEnum
# end
module Foobara
  module LlmBackedQuery
    include Concern

    on_include do
      depends_on Ai::AnswerBot::Ask
    end

    def execute
      determine_serializer
      construct_input_json
      generate_answer
      parse_answer

      parsed_answer
    end

    attr_accessor :serializer, :input_json, :answer, :parsed_answer

    def determine_serializer
      depth = if respond_to?(:association_depth)
                association_depth
              else
                Foobara::JsonSchemaGenerator::AssociationDepth::AGGREGATE
              end

      serializer = case depth
                   when Foobara::JsonSchemaGenerator::AssociationDepth::ATOM
                     Foobara::CommandConnectors::Serializers::AtomicSerializer
                   when Foobara::JsonSchemaGenerator::AssociationDepth::AGGREGATE
                     Foobara::CommandConnectors::Serializers::AggregateSerializer
                   when Foobara::JsonSchemaGenerator::AssociationDepth::PRIMARY_KEY_ONLY
                     # :nocov:
                     raise "PRIMARY_KEY_ONLY depth not yet implemented"
                   # :nocov:
                   else
                     raise "Unknown depth: #{depth}"
                   end

      # cache this?
      self.serializer = serializer.new
    end

    def construct_input_json
      inputs_without_llm_integration_inputs = inputs.except(:llm_model, :association_depth)
      input_json = serializer.serialize(inputs_without_llm_integration_inputs)

      self.input_json = JSON.fast_generate(input_json)
    end

    def generate_answer
      self.answer = run_subcommand!(
        Ai::AnswerBot::Ask,
        model: llm_model,
        instructions: llm_instructions,
        question: input_json
      )
    end

    def llm_instructions
      self.class.llm_instructions
    end

    def parse_answer
      # TODO: should we verify against json-schema or no?
      self.parsed_answer = JSON.parse(answer)
    end

    module ClassMethods
      def inputs_json_schema
        @inputs_json_schema ||= JsonSchemaGenerator.to_json_schema(inputs_type_without_llm_integration_inputs)
      end

      def inputs_type_without_llm_integration_inputs
        return @inputs_type_without_llm_integration_inputs if @inputs_type_without_llm_integration_inputs

        type_declaration = Util.deep_dup(inputs_type.declaration_data)

        element_type_declarations = type_declaration[:element_type_declarations]

        changed = false

        if element_type_declarations.key?(:llm_model)
          changed = true
          element_type_declarations.delete(:llm_model)
        end

        if element_type_declarations.key?(:association_depth)
          changed = true
          element_type_declarations.delete(:association_depth)
        end

        if type_declaration.key?(:defaults)
          if type_declaration[:defaults].key?(:llm_model)
            changed = true
            type_declaration[:defaults].delete(:llm_model)
          end

          if type_declaration[:defaults].key?(:association_depth)
            changed = true
            type_declaration[:defaults].delete(:association_depth)
          end
          if type_declaration[:defaults].empty?
            type_declaration.delete(:defaults)
          end
        end

        @inputs_type_without_llm_integration_inputs = if changed
                                                        domain.foobara_type_from_declaration(type_declaration)
                                                      else
                                                        inputs_type
                                                      end
      end

      def result_json_schema
        @result_json_schema ||= JsonSchemaGenerator.to_json_schema(result_type)
      end

      def llm_instructions
        @llm_instructions ||= <<~INSTRUCTIONS
          You are implementing an API for a command named #{scoped_full_name} which has the following description:

          #{description}#{"  "}

          Here is the inputs JSON schema for the data you will receive:

          #{inputs_json_schema}

          Here is the result JSON schema:

          #{result_json_schema}

          You will receive 1 message containing only JSON data according to the inputs JSON schema above
          and you will generate a JSON response that is a valid response according to the result JSON schema above.

          You will reply with nothing more than the JSON you've generated so that the calling code
          can successfully parse your answer.
        INSTRUCTIONS
      end
    end
  end
end
