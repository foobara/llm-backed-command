require "foobara/all"
# TODO: move serializers to their own project so we don't have to include command_connectors to use them
require "foobara/command_connectors"
require "foobara/ai"
require "foobara/json_schema_generator"

if Foobara::Ai.foobara_all_command.empty?
  # :nocov:
  raise "No api services loaded. " \
        "Did you forget to set a URL/API key env var or a require for either ollama, anthropic, or openai?"
  # :nocov:
end

Foobara::Util.require_directory "#{__dir__}/../../src"

Foobara.project "llm_backed_command", project_path: "#{__dir__}/../../"
