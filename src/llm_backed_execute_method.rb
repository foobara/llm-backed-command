# NOTE: You can add the following inputs if you'd like, or, create methods with these names
# on the class.
#
# inputs do
#   association_depth :symbol, one_of: JsonSchemaGenerator::AssociationDepth, default: AssociationDepth::ATOM
#   llm_model :symbol, one_of: Foobara::Ai::AnswerBot::Types::ModelEnum
# end
module Foobara
  module LlmBackedExecuteMethod
    include Concern

    on_include do
      depends_on Ai::AnswerBot::GenerateNextMessage
      possible_error :could_not_parse_result_json,
                     message: "Could not parse answer",
                     context: {
                       raw_answer: :string,
                       stripped_answer: :string
                     }
    end

    def execute
      determine_serializer
      construct_messages
      generate_answer
      parse_answer

      parsed_answer
    end

    attr_accessor :serializer, :answer, :parsed_answer, :messages

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
                     # :nocov:
                     raise "Unknown depth: #{depth}"
                     # :nocov:
                   end

      # cache this?
      self.serializer = serializer.new
    end

    def generate_answer
      inputs = {
        chat: Ai::AnswerBot::Types::Chat.new(messages:)
      }

      inputs[:temperature] = if respond_to?(:temperature)
                               temperature
                             end || 0

      if respond_to?(:llm_model)
        inputs[:model] = llm_model
      end

      message = run_subcommand!(Ai::AnswerBot::GenerateNextMessage, inputs)

      self.answer = message.content
    end

    def construct_messages
      self.messages = build_messages.map do |message|
        content = message[:content]

        if content.is_a?(String)
          message
        else
          content = serializer.serialize(content)
          message.merge(content: JSON.fast_generate(content))
        end
      end
    end

    def build_messages
      [
        {
          role: :system,
          content: llm_instructions
        },
        {
          role: :user,
          content: inputs.except(:llm_model, :association_depth)
        }
      ]
    end

    def llm_instructions
      self.class.llm_instructions
    end

    def parse_answer
      stripped_answer = answer.gsub(/<THINK>.*?<\/THINK>/mi, "")
      fencepostless_answer = stripped_answer.gsub(/^\s*```\w*\n(.*)```\s*\z/m, "\\1")

      # TODO: should we verify against json-schema or no?
      self.parsed_answer = begin
        JSON.parse(fencepostless_answer)
      rescue JSON::ParserError
        # see if we can extract the last fence-posts content just in case
        last_fence_post_regex = /```\w*\s*\n((?:(?!```).)+)\n```(?:(?!```).)*\z/m

        begin
          match = last_fence_post_regex.match(stripped_answer)

          if match
            fencepostless_answer = match[1]
            JSON.parse(fencepostless_answer)
          else
            # :nocov:
            raise
            # :nocov:
          end
        rescue JSON::ParserError => e
          # TODO: figure out how to test this code path
          # :nocov:
          add_runtime_error :could_not_parse_result_json,
                            "Could not parse result JSON: #{e.message}",
                            raw_answer: answer,
                            stripped_answer: fencepostless_answer
          # :nocov:
        end
      end
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
        @result_json_schema ||= JsonSchemaGenerator.to_json_schema(
          result_type,
          association_depth: JsonSchemaGenerator::AssociationDepth::PRIMARY_KEY_ONLY
        )
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
