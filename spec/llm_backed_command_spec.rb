RSpec.describe Foobara::LlmBackedCommand do
  after do
    Foobara.reset_alls
  end

  let(:command_class) do
    described_class

    stub_class "PossibleUsState", Foobara::Model do
      attributes do
        name :string, :required,
             "A name that potentially might be a name of a US state, spelled correctly or incorrectly"
      end
    end

    stub_class "VerifiedUsState", Foobara::Model do
      attributes do
        possible_us_state PossibleUsState, :required,
                          "The original possible US state that was passed in"
        spelling_correction_required :boolean, :required, "Whether or not the original spelling was correct"
        corrected_spelling :string, :allow_nil,
                           "If the original spelling was incorrect, the corrected spelling will be here"
      end

      def original_spelling
        possible_us_state.name
      end
    end

    stub_class "SelectUsStateNamesAndCorrectTheirSpelling", described_class do
      description <<~DESCRIPTION
        Accepts a list of possible US state names and sorts them into verified to be the name of a
        US state and rejected to be the name of a non-US state, as well as corrects the spelling of
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
        list_of_possible_states [PossibleUsState]
      end

      result do
        verified [VerifiedUsState]
        rejected [PossibleUsState]
      end
    end
  end

  let(:command) { command_class.new(inputs) }
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    {
      list_of_possible_states:
    }
  end

  let(:list_of_possible_states) do
    [
      PossibleUsState.new(name: "Grand Rapids"),
      PossibleUsState.new(name: "Oregon"),
      PossibleUsState.new(name: "Yutah"),
      PossibleUsState.new(name: "Misisipi")
    ]
  end

  let(:llm_model) { "claude-3-7-sonnet-20250219" }

  context "with an llm_model method" do
    before do
      model = llm_model
      command_class.define_method :llm_model do
        model
      end
    end

    it "is successful",  vcr: { record: :none } do
      expect(outcome).to be_success

      expect(result[:verified].length).to eq(3)

      expect(result[:verified][0].possible_us_state.name).to eq("Oregon")
      expect(result[:verified][0].spelling_correction_required).to be(false)
      expect(result[:verified][0].corrected_spelling).to be_nil

      expect(result[:verified][1].possible_us_state.name).to eq("Yutah")
      expect(result[:verified][1].original_spelling).to eq("Yutah")
      expect(result[:verified][1].spelling_correction_required).to be(true)
      expect(result[:verified][1].corrected_spelling).to eq("Utah")

      expect(result[:verified][2].possible_us_state.name).to eq("Misisipi")
      expect(result[:verified][2].spelling_correction_required).to be(true)
      expect(result[:verified][2].corrected_spelling).to eq("Mississippi")

      expect(result[:rejected].length).to eq(1)

      expect(result[:rejected][0].name).to eq("Grand Rapids")
    end
  end

  context "when adding llm_model and association_depth inputs" do
    before do
      command_class.add_inputs do
        llm_model :symbol, one_of: Foobara::Ai::AnswerBot::Types::ModelEnum, default: "claude-3-7-sonnet-20250219"
        association_depth :symbol,
                          one_of: Foobara::JsonSchemaGenerator::AssociationDepth,
                          default: Foobara::JsonSchemaGenerator::AssociationDepth::ATOM
      end
    end

    it "is successful", vcr: { record: :none } do
      expect(outcome).to be_success

      expect(result[:verified].length).to eq(3)
      expect(result[:verified][2].corrected_spelling).to eq("Mississippi")

      expect(result[:rejected].length).to eq(1)
      expect(result[:rejected][0].name).to eq("Grand Rapids")
    end

    context "when the model produces answer that have a <THINK></THINK> section" do
      let(:llm_model) { "deepseek-r1:70b" }

      let(:inputs) do
        {
          list_of_possible_states:,
          llm_model:
        }
      end

      it "is successful", vcr: { record: :none } do
        expect(outcome).to be_success

        expect(result[:verified].length).to eq(3)
        expect(result[:verified][2].corrected_spelling).to eq("Mississippi")

        expect(result[:rejected].length).to eq(1)
        expect(result[:rejected][0].name).to eq("Grand Rapids")
      end
    end
  end

  context "with a simpler command" do
    let(:command_class) do
      mixin = Foobara::LlmBackedExecuteMethod

      stub_module "Math"
      stub_class "Math::ComputeExponent", Foobara::Command do
        include mixin

        # description "Accepts a base and exponent and returns the base raised to the exponent."

        inputs do
          base :integer, :required
          exponent :integer, :required
          llm_model Foobara::Ai::AnswerBot::Types.model_enum, default: "deepseek-r1:14b"
        end

        result :integer
      end
    end

    let(:base) { 2 }
    let(:exponent) { 3 }
    let(:llm_model) { "deepseek-r1:14b" }

    let(:inputs) do
      {
        base:,
        exponent:,
        llm_model:
      }
    end

    it "is successful", vcr: { record: :none } do
      expect(outcome).to be_success

      expect(result).to eq(8)
    end
  end
end
