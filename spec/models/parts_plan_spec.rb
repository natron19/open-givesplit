require "rails_helper"

RSpec.describe PartsPlan, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:parts_plan)).to be_valid
    end

    it "requires a need" do
      expect(build(:parts_plan, need: nil)).not_to be_valid
    end

    it "accepts every known status and rejects others" do
      PartsPlan::STATUSES.each { |s| expect(build(:parts_plan, status: s)).to be_valid }
      expect(build(:parts_plan, status: "unknown")).not_to be_valid
    end

    it "lists the statuses and the code-enforced counts" do
      expect(PartsPlan::STATUSES).to eq(%w[pending completed failed])
      expect(PartsPlan::PART_COUNT).to eq(8..14)
      expect(PartsPlan::MAX_OWNER_QUESTIONS).to eq(2)
    end
  end

  describe "associations" do
    it "has a user through its need, and parts in position order" do
      plan = create(:parts_plan, :completed)
      expect(plan.user).to eq(plan.need.user)
      expect(plan.parts.map(&:position)).to eq((1..8).to_a)
    end
  end

  describe "defaults" do
    it "starts pending with no questions" do
      plan = PartsPlan.create!(need: create(:need))
      expect(plan.status).to eq("pending")
      expect(plan.questions_for_owner).to eq([])
    end
  end

  describe "#numbers_sentence" do
    it "states the money total and the non-money asks as numbers, with no bar or percentage" do
      plan = create(:parts_plan, :completed)
      expect(plan.numbers_sentence).to eq("$400 in money across 2 Parts (1 with an amount), and 6 asks for time, tools, skills and materials.")
      expect(plan.numbers_sentence).not_to include("%")
    end

    it "says when there is no money at all" do
      plan = create(:parts_plan, :completed)
      plan.parts.select(&:money?).each(&:destroy)
      expect(plan.reload.numbers_sentence).to eq("No money, and 6 asks for time, tools, skills and materials.")
    end

    it "uses the need's currency" do
      plan = create(:parts_plan, :completed, need: create(:need, currency: "GBP"))
      expect(plan.numbers_sentence).to start_with("£400 in money")
    end
  end

  describe "#stale?" do
    it "is true when the need changed after the plan" do
      plan = create(:parts_plan, :completed, generated_at: 1.hour.ago)
      plan.need.update!(rough_budget: "About $2,000")
      expect(plan.stale?).to be(true)
    end

    it "is false when the plan is newer than the need" do
      plan = create(:parts_plan, :completed, generated_at: 1.minute.from_now)
      expect(plan.stale?).to be(false)
    end
  end

  describe "#to_markdown" do
    it "includes the name, the disclaimer, the numbers, every part, the questions, and the need" do
      plan = create(:parts_plan, :completed)
      md = plan.to_markdown
      expect(md).to include("# Hall kitchen repair", "AI-generated", "Money never moves through this app")
      expect(md).to include(plan.numbers_sentence)
      expect(md).to include("1. **About $400 for two stove burners** (Money, About $400, a guess to check)")
      expect(md).to include("**Saturday clean-up, 4 hours, two people** (Hours, 8 hours)")
      expect(md).to include("## Questions for you", "Is the stove gas or electric?")
      expect(md).to include(plan.need.need_text)
    end

    it "names the file after the project" do
      expect(create(:parts_plan, :completed).markdown_filename).to eq("hall-kitchen-repair-parts.md")
    end
  end
end
