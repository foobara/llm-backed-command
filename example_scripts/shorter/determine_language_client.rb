#!/usr/bin/env ruby

require "foobara/remote_imports"

Foobara::RemoteImports::ImportCommand.run!(manifest_url: "http://localhost:9292/manifest", cache: true)

puts DetermineLanguage.run!(code_snippet: "System.out.println")
