require "rails_helper"

RSpec.describe Part, type: :model do
  it "is valid with the factory attributes" do
    expect(build(:part)).to be_valid
  end

  it "requires a parts plan, a known kind, a name of at most 120 characters, and a position" do
    expect(build(:part, parts_plan: nil)).not_to be_valid
    expect(build(:part, kind: "favour")).not_to be_valid
    expect(build(:part, name: "")).not_to be_valid
    expect(build(:part, name: "x" * 121)).not_to be_valid
    expect(build(:part, position: nil)).not_to be_valid
  end

  it "rejects a negative amount and a zero quantity" do
    expect(build(:part, kind: "money", amount: -1, quantity: nil)).not_to be_valid
    expect(build(:part, quantity: 0)).not_to be_valid
  end

  describe "#size_label" do
    it "shows a money amount, marked when it is a guess" do
      expect(build(:part, kind: "money", amount: 900, price_is_guess: true, quantity: nil).size_label("USD")).to eq("About $900, a guess to check")
      expect(build(:part, kind: "money", amount: 1200, price_is_guess: false, quantity: nil).size_label("CAD")).to eq("CA$1,200")
    end

    it "shows a quantity and unit for non-money parts, and nothing when there is none" do
      expect(build(:part, quantity: 16, unit: "hours").size_label("USD")).to eq("16 hours")
      expect(build(:part, quantity: 2.5, unit: "hours").size_label("USD")).to eq("2.5 hours")
      expect(build(:part, kind: "money", amount: nil, quantity: nil).size_label("USD")).to be_nil
    end
  end
end
