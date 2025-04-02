#!/usr/bin/env ruby

require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/remote_imports"

Foobara::RemoteImports::ImportCommand.run!(
  manifest_url: "http://localhost:9292/manifest",
  to_import: "DetermineLanguage",
  cache: true
)

require "foobara/anthropic_api"
require "foobara/open_ai_api"
require "foobara/ollama_api"

code_snippet = "System.out.println"
llm_model = "claude-3-7-sonnet-20250219"
# llm_model = "gpt-3.5-turbo"
# llm_model = "deepseek-r1:32b"

puts DetermineLanguage.run!(llm_model:, code_snippet:)
