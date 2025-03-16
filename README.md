# Foobara::LlmBackedCommand/Foobara::LlmBackedExecuteMethod

Provides a clean and quick way to implement a Foobara::Command that defers to an LLM for the answer

<!-- TOC -->
* [Foobara::LlmBackedCommand/Foobara::LlmBackedExecuteMethod](#foobarallmbackedcommandfoobarallmbackedexecutemethod)
  * [Installation](#installation)
  * [Usage](#usage)
    * [Choosing a different model and llm service](#choosing-a-different-model-and-llm-service)
    * [Using it as a mixin instead of a class](#using-it-as-a-mixin-instead-of-a-class)
    * [Typical Foobara stuff: exposing it on the command-line](#typical-foobara-stuff-exposing-it-on-the-command-line)
    * [Exposing commands through Rack](#exposing-commands-through-rack)
    * [Exposing commands through Rails](#exposing-commands-through-rails)
    * [Use with models](#use-with-models)
    * [Use with entities](#use-with-entities)
    * [Complete scripts to play with](#complete-scripts-to-play-with)
  * [Contributing](#contributing)
  * [License](#license)
<!-- TOC -->

## Installation

Typical stuff: add `gem "foobara-llm-backed-command` to your Gemfile or .gemspec file. Or even just
`gem install foobara-llm-backed-command` if just playing with it directly in scripts.

## Usage

To play with these examples you can do `gem install foobara-llm-backed-command foobara-anthropic-api`
and then the following:

```ruby
ENV["ANTHROPIC_API_KEY"] = "<your key here>"

require 'foobara/llm_backed_command'

class DetermineLanguage < Foobara::LlmBackedCommand
  inputs code_snippet: :string
  result most_likely: :string, probabilities: { ruby: :float, c: :float, smalltalk: :float, java: :float }
end

puts DetermineLanguage.run!(code_snippet: "puts 'Hello, World'")
```

Running this script outputs:

```
$ ./demo
{most_likely: "ruby", probabilities: {ruby: 0.95, c: 0.01, smalltalk: 0.02, java: 0.02}}
```

Here we have only specified the command name and the inputs/result. Our LLM of choice
will be used to get the answer, and it will be structured according to the result type.

The default LLM model is claude-3-7-sonnet, but you can use others:

### Choosing a different model and llm service

One way to do this is by creating an input called `llm_model`

```ruby
ENV["ANTHROPIC_API_KEY"] = "<your key here>"
ENV["OPENAI_API_KEY"] = "<your key here>"
ENV["OLLAMA_API_URL"] = "<your ollama API if different than http://localhost:11434>"

require "foobara/anthropic_api"
require "foobara/open_ai_api"
require "foobara/ollama_api"
require 'foobara/llm_backed_command'

class DetermineLanguage < Foobara::LlmBackedCommand
  inputs do
    code_snippet :string, :required
    llm_model Foobara::Ai::AnswerBot::Types.model_enum, default: "claude-3-7-sonnet-20250219"
  end

  result most_likely: :string, probabilities: { ruby: :float, c: :float, smalltalk: :float, java: :float }
end

inputs = { llm_model: "chat-gpt-3-5-turbo", code_snippet: "puts 'Hello, World'" }
command = DetermineLanguage.new(inputs)
outcome = command.run

puts outcome.success? ? outcome.result : outcome.errors_hash
```

### Using it as a mixin instead of a class

If you need the inheritance slot for some other command base class, you can use the mixin:

```ruby
class DetermineLanguage < Foobara::Command
  include Foobara::LlmBackedExecuteMethod

  inputs code_snippet: :string
  result most_likely: :string, probabilities: { ruby: :float, c: :float, smalltalk: :float, java: :float }
end
```

### Typical Foobara stuff: exposing it on the command-line

Probably best to refer to Foobara for details instead of turning this README.md into a Foobara tutorial, but
these can be used as any other Foobara command. So exposing
the command on the command line is easy (requires `gem install foobara-sh-cli-connector fooara-dotenv-loader`)
(switching to dotenv for convenience):

```ruby
#!/usr/bin/env ruby

require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/anthropic_api"
require "foobara/open_ai_api"
require "foobara/ollama_api"
require "foobara/llm_backed_command"
require "foobara/sh_cli_connector"

class DetermineLanguage < Foobara::LlmBackedCommand
  inputs do
    code_snippet :string, :required
    llm_model Foobara::Ai::AnswerBot::Types.model_enum, default: "claude-3-7-sonnet-20250219"
  end
  result most_likely: :string, probabilities: { ruby: :float, c: :float, smalltalk: :float, java: :float }
end

Foobara::CommandConnectors::ShCliConnector.new(single_command_mode: DetermineLanguage).run(ARGV)
```

which allows:

```
$ ./determine-language --help
Usage: determine-language [INPUTS]

Inputs:

 -c, --code-snippet CODE_SNIPPET  Required
 -l, --llm-model LLM_MODEL        One of: babbage-002, chatgpt-4o-latest, claude-2.0, claude-2.1,
                                    claude-3-5-haiku-20241022, claude-3-5-sonnet-20240620, claude-3-5-sonnet-20241022,
                                    claude-3-7-sonnet-20250219, claude-3-haiku-20240307, claude-3-opus-20240229,
                                    claude-3-sonnet-20240229, dall-e-2, dall-e-3, davinci-002, gpt-3.5-turbo,
                                    gpt-3.5-turbo-0125, gpt-3.5-turbo-1106, gpt-3.5-turbo-16k, gpt-3.5-turbo-instruct,
                                    gpt-3.5-turbo-instruct-0914, gpt-4, gpt-4-0125-preview, gpt-4-0613,
                                    gpt-4-1106-preview, gpt-4-turbo, gpt-4-turbo-2024-04-09, gpt-4-turbo-preview,
                                    gpt-4.5-preview, gpt-4.5-preview-2025-02-27, gpt-4o, gpt-4o-2024-05-13,
                                    gpt-4o-2024-08-06, gpt-4o-2024-11-20, gpt-4o-audio-preview, gpt-4o-audio-preview-2024-10-01,
                                    gpt-4o-audio-preview-2024-12-17, gpt-4o-mini, gpt-4o-mini-2024-07-18,
                                    gpt-4o-mini-audio-preview, gpt-4o-mini-audio-preview-2024-12-17,
                                    gpt-4o-mini-realtime-preview, gpt-4o-mini-realtime-preview-2024-12-17,
                                    gpt-4o-mini-search-preview, gpt-4o-mini-search-preview-2025-03-11,
                                    gpt-4o-realtime-preview, gpt-4o-realtime-preview-2024-10-01, gpt-4o-realtime-preview-2024-12-17,
                                    gpt-4o-search-preview, gpt-4o-search-preview-2025-03-11, llama3:8b,
                                    o1, o1-2024-12-17, o1-mini, o1-mini-2024-09-12, o1-preview, o1-preview-2024-09-12,
                                    o3-mini, o3-mini-2025-01-31, omni-moderation-2024-09-26, omni-moderation-latest,
                                    smollm2:135m, text-embedding-3-large, text-embedding-3-small, text-embedding-ada-002,
                                    tts-1, tts-1-1106, tts-1-hd, tts-1-hd-1106, whisper-1.
                                  Default: "claude-3-7-sonnet-20250219"
```

Running the program:

```
$ ./determine-language --code-snippet "Transcript show: 'Hello, World'"
most_likely: "smalltalk",
probabilities: {
  ruby: 0.1,
  c: 0.05,
  smalltalk: 0.8,
  java: 0.05
}
```

### Exposing commands through Rack

Or you can spin up a quick json API either through Rack or the Rails router. Here's an example with the rack connector
(requires `gem install foobara-rack-controller rackup puma`):

```ruby
#!/usr/bin/env ruby

require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/llm_backed_command"
require "foobara/rack_connector"
require "rackup/server"

class DetermineLanguage < Foobara::LlmBackedCommand
  inputs code_snippet: :string
  result probabilities: { ruby: :float, c: :float, smalltalk: :float, java: :float },
         most_likely: :string
end

command_connector = Foobara::CommandConnectors::Http::Rack.new
command_connector.connect(DetermineLanguage)

Rackup::Server.start(app: command_connector)
```

After we run this script we can hit it with curl:

```
$ curl http://localhost:9292/run/DetermineLanguage?code_snippet=System.out.println
{"probabilities":{"ruby":0.05,"c":0.1,"smalltalk":0.05,"java":0.8},"most_likely":"java"}
```

And we can run it from other systems in either Ruby or TypeScript.

In Ruby (requires `gem install foobara-remote-imports`):

```ruby
#!/usr/bin/env ruby

require "foobara/remote_imports"

Foobara::RemoteImports::ImportCommand.run!(manifest_url: "http://localhost:9292/manifest", cache: true)

puts DetermineLanguage.run!(code_snippet: "System.out.println")
```

This outputs:

```
$ ./determine-language-client
{probabilities: {ruby: 0.05, c: 0.05, smalltalk: 0.1, java: 0.8}, most_likely: "java"}
```

And we can also generate a remote command in TypeScript (requires `gem install foob`)

From inside a TypeScript project:

```
$ foob g typescript-remote-commands --manifest-url http://localhost:9292/manifest
```

This will generate code so that we can do:

```TypeScript
import { DetermineLanguage } from "./DetermineLanguage"

const command = new DetermineLanguage({code_snippet: "System.out.println"})
const outcome = await command.run()

if (outcome.isSuccess) {
  console.log(outcome.result)
} else {
  console.error(outcome.errors_hash)
}
```

and everything will be fully typed, inputs, result, etc.

### Exposing commands through Rails

This has become too much of a Foobara tutorial so instead please refer to
https://github.com/foobara/rails-command-connector

### Use with models

You can of course use this with whatever Foobara concepts you want, including models (and entities to some extent.)

Here's more complex example that accepts data encapsulated in model instances and returns model instances:

```ruby
#!/usr/bin/env ruby

require "foobara/load_dotenv"

Foobara::LoadDotenv.run!(env: "development", dir: __dir__)

require "foobara/anthropic_api"
# require "foobara/open_ai_api"
# require "foobara/ollama_api"
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

class SelectUsStateNamesAndCorrectTheirSpelling < Foobara::LlmBackedCommand
  description <<~DESCRIPTION
    Accepts a list of possible US state names and sorts them into verified to be the name of a
    US state and rejected to be the name of a non-US state, as well as correcting the spelling of
    the US state name if it's not correct.

    example:

    If you pass in ["Kalifornia", "Los Angeles", "New York"] the result will be:

    result[:verified].length # => 2
    result[:verified][0].possible_us_state.name # => "Kalifornia"
    result[:verified][0].spelling_correction_required # => true#{" "}
    result[:verified][0].corrected_spelling # => "California"
    result[:verified][1].possible_us_state.name # => "New York"
    result[:verified][1].spelling_correction_required # => false
    result[:verified][1].corrected_spelling # => nil

    result[:rejected].length # => 1
    result[:rejected][0].name # => "Los Angeles"
  DESCRIPTION

  inputs do
    list_of_possible_us_states [PossibleUsState]
    llm_model :string, default: "claude-3-7-sonnet-20250219"
  end

  result do
    verified [VerifiedUsState]
    rejected [PossibleUsState]
  end
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

command = SelectUsStateNamesAndCorrectTheirSpelling.new(list_of_possible_us_states:)
result = command.run!

puts "Considering:"
list_of_possible_us_states.each do |possible_us_state|
  puts "  #{possible_us_state.name}"
end
puts

puts "#{result[:verified].length} were verified as US states:"
result[:verified].each do |verified_us_state|
  puts "  #{verified_us_state.corrected_spelling || verified_us_state.possible_us_state.name}"
  if verified_us_state.spelling_correction_required
    puts "    original incorrect spelling: #{verified_us_state.possible_us_state.name}"
  end
end

puts
puts "#{result[:rejected].length} were rejected as non-US states:"
result[:rejected].each do |rejected_us_state|
  puts "  #{rejected_us_state.name}"
end
```

This script outputs:

```
Considering:
  Grand Rapids
  Oregon
  Yutah
  Misisipi
  Tacoma
  Kalifornia
  Los Angeles
  New York

5 were verified as US states:
  Oregon
  Utah
    original incorrect spelling: Yutah
  Mississippi
    original incorrect spelling: Misisipi
  California
    original incorrect spelling: Kalifornia
  New York

3 were rejected as non-US states:
  Grand Rapids
  Tacoma
  Los Angeles
```

Note that we were able to access model attributes by methods just fine, and we didn't write any logic on how
to spell check or any logic on how determine what is or is not a US state.

### Use with entities

Unclear how practical using entities in this way would be, but, here's an interesting
example of asking a question about some persisted records:

```ruby
#!/usr/bin/env ruby

require "foobara/load_dotenv"

Foobara::LoadDotenv.run!(env: "development", dir: __dir__)

require "foobara/llm_backed_command"
require "foobara/sh_cli_connector"
require "foobara/local_files_crud_driver"

Foobara::Persistence.default_crud_driver = Foobara::LocalFilesCrudDriver.new

class Capybara < Foobara::Entity
  attributes do
    id :integer
    name :string, :required
    age :integer, :required
  end
  primary_key :id
end

class CreateCapybara < Foobara::Command
  inputs Capybara.attributes_for_create
  result Capybara

  def execute
    create_capybara

    capybara
  end

  attr_accessor :capybara

  def create_capybara
    self.capybara = Capybara.create(inputs)
  end
end

class SelectOldestCapybara < Foobara::LlmBackedCommand
  inputs capybaras: [Capybara]
  result Capybara
end

connector = Foobara::CommandConnectors::ShCliConnector.new

connector.connect(CreateCapybara)
connector.connect(SelectOldestCapybara)

connector.run(ARGV)
```

We can create some capybara records like this:

```
$ ./oldest-capybara-example CreateCapybara --age 100 --name Fumiko
age: 100,
name: "Fumiko",
id: 1
$ ./oldest-capybara-example CreateCapybara --age 200 --name Barbara
age: 200,
name: "Barbara",
id: 2
$ ./oldest-capybara-example CreateCapybara --age 300 --name Basil
age: 300,
name: "Basil",
id: 3
```

And then ask who is older, Barbara or Basil, like so:

```
$ ./oldest-capybara-example SelectOldestCapybara --capybaras 2 3
id: 3,
name: "Basil",
age: 300
```

Basil is older.  Pretty crazy we didn't have to write any logic about age comparisons at all.
And our SelectOldestCapybara command is only 4 lines long as a result.

### Complete scripts to play with

There are various scripts you can play with in [example_scripts](example_scripts) that you can play with.

That directory also has a Gemfile if helpful for pulling in dependencies
and you can use `bundle exec` there if needed.

## Contributing

Bug reports and pull requests are welcome on GitHub
at https://github.com/foobara/llm-backed-command

## License

This project is licensed under the MPL-2.0 license. Please see LICENSE.txt for more info.
