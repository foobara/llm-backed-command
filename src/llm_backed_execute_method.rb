# NOTE: You can add the following inputs if you'd like, or, create methods with these names
# on the class.
#
# inputs do
#   association_depth :symbol, one_of: AssociationDepth, default: AssociationDepth::ATOM
#   llm_model :symbol, one_of: Foobara::Ai::AnswerBot::Types::ModelEnum
# end
module Foobara
  module LlmBackedExecuteMethod
    include Concern

    LLM_INTEGRATION_KEYS = [
      :llm_model,
      :association_depth,
      :user_association_depth,
      :assistant_association_depth
    ].freeze

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
      determine_user_association_depth
      determine_assistant_association_depth
      determine_user_serializer
      determine_assistant_serializer
      determine_llm_instructions
      construct_messages
      generate_answer
      parse_answer
      attempt_to_recover_from_bad_format

      final_answer
    end

    attr_accessor :final_answer, :answer, :parsed_answer, :messages, :assistant_serializer, :user_serializer,
                  :computed_assistant_association_depth, :computed_user_association_depth,
                  :llm_instructions

    def determine_assistant_association_depth
      self.computed_assistant_association_depth = if respond_to?(:assistant_association_depth)
                                                    assistant_association_depth
                                                  elsif respond_to?(:association_depth)
                                                    association_depth
                                                  else
                                                    Foobara::AssociationDepth::PRIMARY_KEY_ONLY
                                                  end
    end

    def determine_assistant_serializer
      self.assistant_serializer = depth_to_serializer(computed_assistant_association_depth)
    end

    def determine_user_association_depth
      self.computed_user_association_depth = if respond_to?(:user_association_depth)
                                               user_association_depth
                                             elsif respond_to?(:association_depth)
                                               association_depth
                                             else
                                               Foobara::AssociationDepth::ATOM
                                             end
    end

    def determine_user_serializer
      self.user_serializer = depth_to_serializer(computed_user_association_depth)
    end

    def depth_to_serializer(depth)
      case depth
      when Foobara::AssociationDepth::ATOM
        Foobara::CommandConnectors::Serializers::AtomicSerializer
      when Foobara::AssociationDepth::AGGREGATE
        Foobara::CommandConnectors::Serializers::AggregateSerializer
      when Foobara::AssociationDepth::PRIMARY_KEY_ONLY
        Foobara::CommandConnectors::Serializers::EntitiesToPrimaryKeysSerializer
      else
        # :nocov:
        raise "Unknown depth: #{depth}"
        # :nocov:
      end.instance
    end

    def generate_answer
      inputs = {
        chat: Ai::AnswerBot::Types::Chat.new(messages:)
      }

      # NOTE: some models don't allow 0 such as o1.  Manually set to 1 in calling code for such models for now.
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
          serializer = if message[:role] == :user
                         user_serializer
                       else
                         assistant_serializer
                       end

          content = serializer.serialize(content)
          message.merge(content: JSON.fast_generate(content))
        end
      end
    end

    def determine_llm_instructions
      self.llm_instructions = self.class.llm_instructions(
        computed_user_association_depth,
        computed_assistant_association_depth
      )
    end

    def build_messages
      [
        {
          role: :system,
          content: llm_instructions
        },
        {
          role: :user,
          content: inputs.except(*LLM_INTEGRATION_KEYS)
        }
      ]
    end

    def parse_answer
      stripped_answer = answer.gsub(/<THINK>.*?<\/THINK>/mi, "")
      # For some reason sometimes deepseek-r1:32b starts the answer with "\n\n</think>\n\n"
      # so removing it as a special case
      stripped_answer = stripped_answer.gsub(/\A\s*<\/?think>\s*/mi, "")
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

    # Sometimes we get {"result": "whatever"} instead of just "whatever" from some smaller models.
    # Let's detect that and handle it...
    def attempt_to_recover_from_bad_format
      self.final_answer = if parsed_answer.is_a?(::Hash) && parsed_answer.keys == ["result"]
                            result_type = self.class.result_type

                            # TODO: implement a Type#valid? method
                            if result_type.process_value(parsed_answer).success?
                              parsed_answer
                            else
                              result = parsed_answer["result"]

                              if result_type.process_value(result).success?
                                result
                              else
                                # :nocov:
                                parsed_answer
                                # :nocov:
                              end
                            end
                          else
                            parsed_answer
                          end
    end

    module ClassMethods
      def inputs_json_schema(association_depth)
        JsonSchemaGenerator.to_json_schema(
          inputs_type_without_llm_integration_inputs,
          association_depth:
        )
      end

      def inputs_type_without_llm_integration_inputs
        type_declaration = Util.deep_dup(inputs_type.declaration_data)

        element_type_declarations = type_declaration[:element_type_declarations]

        changed = false

        LLM_INTEGRATION_KEYS.each do |key|
          if element_type_declarations.key?(key)
            changed = true
            element_type_declarations.delete(key)
          end
        end

        if type_declaration.key?(:defaults)
          LLM_INTEGRATION_KEYS.each do |key|
            if type_declaration[:defaults].key?(key)
              changed = true
              type_declaration[:defaults].delete(key)
            end
          end

          if type_declaration[:defaults].empty?
            type_declaration.delete(:defaults)
          end
        end

        if changed
          domain.foobara_type_from_declaration(type_declaration)
        else
          inputs_type
        end
      end

      def result_json_schema(association_depth)
        JsonSchemaGenerator.to_json_schema(
          result_type,
          association_depth:
        )
      end

      def llm_instructions(user_association_depth, assistant_association_depth)
        key = [user_association_depth, assistant_association_depth]

        @llm_instructions_cache ||= {}

        if @llm_instructions_cache.key?(key)
          # :nocov:
          @llm_instructions_cache[key]
          # :nocov:
        else
          @llm_instructions_cache[key] = build_llm_instructions(user_association_depth, assistant_association_depth)
        end
      end

      def build_llm_instructions(user_association_depth, assistant_association_depth)
        <<~INSTRUCTIONS
          You are implementing an API for a command named #{scoped_full_name} which has the following description:

          #{description}

          Here is the inputs JSON schema for the data you will receive:

          #{inputs_json_schema(user_association_depth)}

          Here is the result JSON schema:

          #{result_json_schema(assistant_association_depth)}

          You will receive 1 message containing only JSON data according to the inputs JSON schema above
          and you will generate a JSON response that is a valid response according to the result JSON schema above.

          You will reply with nothing more than the JSON you've generated so that the calling code
          can successfully parse your answer.
        INSTRUCTIONS
      end
    end
  end
end
