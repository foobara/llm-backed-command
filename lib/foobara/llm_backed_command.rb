require "foobara/all"
# TODO: move serializers to their own project so we don't have to include command_connectors to use them
require "foobara/command_connectors"
require "foobara/ai"
require "foobara/json_schema_generator"

Foobara::Util.require_directory "#{__dir__}/../../src"

Foobara::Monorepo.project "llm_backed_query", project_path: "#{__dir__}/../../"
