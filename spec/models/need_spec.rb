require "rails_helper"

RSpec.describe Need, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:need)).to be_valid
    end

    it "requires a user" do
      expect(build(:need, user: nil)).not_to be_valid
    end

    it "requires need_text of 20 to 1500 characters" do
      expect(build(:need, need_text: "")).not_to be_valid
      expect(build(:need, need_text: "A garden")).not_to be_valid
      expect(build(:need, need_text: "x" * 1501)).not_to be_valid
      expect(build(:need, need_text: "x" * 1500)).to be_valid
    end

    it "accepts every known currency and rejects others" do
      Need::CURRENCIES.each { |c| expect(build(:need, currency: c)).to be_valid }
      expect(build(:need, currency: "BTC")).not_to be_valid
    end

    it "allows blank community_context and rough_budget but caps them" do
      expect(build(:need, community_context: nil, rough_budget: nil)).to be_valid
      expect(build(:need, community_context: "x" * 1001)).not_to be_valid
      expect(build(:need, rough_budget: "x" * 201)).not_to be_valid
    end

    it "requires at least one kind" do
      need = build(:need, kinds: [])
      expect(need).not_to be_valid
      expect(need.errors[:kinds].first).to include("at least one kind")
    end

    it "rejects an unknown kind" do
      need = build(:need, kinds: %w[hours favours])
      expect(need).not_to be_valid
      expect(need.errors[:kinds].first).to include("favours")
    end

    it "rejects money as the only kind, since at least half the Parts must not be money" do
      need = build(:need, kinds: %w[money])
      expect(need).not_to be_valid
      expect(need.errors[:kinds].first).to include("not money")
    end

    it "accepts any non-money kind on its own" do
      Need::NON_MONEY_KINDS.each { |k| expect(build(:need, kinds: [ k ])).to be_valid }
    end

    it "drops the blank value a checkbox group submits and keeps the kinds in order" do
      need = build(:need, kinds: [ "", "skill", "money", "skill" ])
      need.valid?
      expect(need.kinds).to eq(%w[money skill])
    end
  end

  describe "constants" do
    it "lists the five kinds of Part, each with a label and a hint" do
      expect(Need::KINDS).to eq(%w[money materials tool_loan hours skill])
      expect(Need::NON_MONEY_KINDS).to eq(%w[materials tool_loan hours skill])
      expect(Need::KIND_LABELS.keys).to eq(Need::KINDS)
      expect(Need::KIND_HINTS.keys).to eq(Need::KINDS)
    end
  end

  describe "associations" do
    it "destroys its parts plans and their parts" do
      need = create(:need)
      create(:parts_plan, :completed, need: need)
      expect { need.destroy }.to change(PartsPlan, :count).by(-1).and change(Part, :count).by(-8)
    end

    it "returns the newest plan as latest_parts_plan" do
      need = create(:need)
      create(:parts_plan, :completed, need: need, generated_at: 2.days.ago)
      newest = create(:parts_plan, :completed, need: need, generated_at: 1.hour.ago)
      expect(need.reload.latest_parts_plan).to eq(newest)
    end

    it "is destroyed with its user" do
      need = create(:need)
      expect { need.user.destroy }.to change(Need, :count).by(-1)
    end
  end

  describe "#heading" do
    it "uses the latest plan's project name, or the start of the need" do
      need = create(:need, need_text: "We want a garden behind the laundromat with six raised beds and a tap.")
      expect(need.heading).to start_with("We want a garden")
      create(:parts_plan, :completed, need: need)
      expect(need.reload.heading).to eq("Hall kitchen repair")
    end
  end

  describe "#ai_variables" do
    it "sends the need, the enabled kinds, and placeholders for blanks, and nothing about the user" do
      need = build(:need, kinds: %w[hours skill], rough_budget: "", community_context: nil, currency: "GBP")
      vars = need.ai_variables
      expect(vars.keys).to eq(%i[need_text enabled_kinds currency rough_budget community_context])
      expect(vars[:enabled_kinds]).to eq("hours, skill")
      expect(vars[:currency]).to eq("GBP")
      expect(vars[:rough_budget]).to eq("Not stated")
      expect(vars[:community_context]).to eq("Not stated")
      expect(vars.values.join).not_to include(need.user.name, need.user.email)
    end

    it "matches every {{variable}} in the seeded template" do
      expect { Rails.application.load_seed }.to output(/givesplit_parts_v1/).to_stdout
      template = AiTemplate.find_by!(name: "givesplit_parts_v1")
      expect(template.variable_names.map(&:to_sym)).to match_array(build(:need).ai_variables.keys)
    end
  end
end
