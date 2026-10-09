require "rails_helper"

# evals:run calls the template directly, not PartsPlansController#parse_plan!, so the case file mirrors the
# code-enforced rules as deterministic checks. This spec keeps the mirror honest: each pattern must agree with
# the Ruby rule it copies.
RSpec.describe "evals/cases/givesplit_parts_v1.yml" do
  let(:file)  { Evals::CaseFile.new(Rails.root.join("evals/cases/givesplit_parts_v1.yml")) }
  let(:raw)   { YAML.load_file(Rails.root.join("evals/cases/givesplit_parts_v1.yml"), aliases: true) }
  let(:half)  { raw.dig("rule_patterns", "half_not_money") }
  let(:pay)   { raw.dig("rule_patterns", "no_payment_details") }

  def passes?(pattern, output)
    context = Evals::Checks::Context.new(output: output, variables: {}, trace: [], duration_ms: 0)
    Evals::Checks.run({ "type" => "matches", "pattern" => pattern }, context).first
  end

  def plan_json(money, other)
    parts = Array.new(money) { |i| { "kind" => "money", "name" => "Money #{i}" } } +
            Array.new(other) { |i| { "kind" => %w[materials tool_loan hours skill][i % 4], "name" => "Ask #{i}" } }
    JSON.pretty_generate("project_name" => "X", "description" => "Y", "parts" => parts.shuffle(random: Random.new(money * 31 + other)))
  end

  it "has 8 cases: 3 golden, 2 edge, 2 adversarial, 1 benign" do
    expect(file.template).to eq("givesplit_parts_v1")
    expect(file.cases.size).to eq(8)
    expect(file.cases.map { |c| c["kind"] }.tally).to eq("golden" => 3, "edge" => 2, "adversarial" => 2, "benign" => 1)
    expect(file.rubric.map { |r| r["dimension"] }).to eq(%w[accurate useful steerable])
  end

  it "gives every case the variables the seeded template needs" do
    expected = %w[need_text enabled_kinds currency rough_budget community_context]
    file.cases.each { |kase| expect(kase["variables"].keys).to match_array(expected), kase["id"] }
  end

  it "mirrors every code-enforced rule in the adversarial rule-break case" do
    kase   = file.cases.find { |c| c["id"] == "adversarial_money_only_with_payment_details" }
    checks = kase["checks"]
    expect(checks).to include(a_hash_including("type" => "count_between", "path" => "parts", "min" => 8, "max" => 14))
    expect(checks).to include(a_hash_including("type" => "values_in", "path" => "parts", "field" => "kind",
                                               "allowed" => kase["variables"]["enabled_kinds"].split(", ")))
    expect(checks).to include(a_hash_including("type" => "matches", "pattern" => half))
    expect(checks).to include(a_hash_including("type" => "matches", "pattern" => pay))
  end

  it "half_not_money agrees with the parser for every mix of 8 to 14 parts" do
    combos   = (8..14).flat_map { |total| (0..total).map { |money| [ money, total - money ] } }
    by_regex = combos.map { |money, other| passes?(half, plan_json(money, other)) }
    by_rule  = combos.map { |money, other| other * 2 >= money + other }
    expect(by_regex).to eq(by_rule)
  end

  describe "no_payment_details pattern" do
    [
      "paypal.me/hollowfieldfc", "https://example.org", "Venmo the coach", "account number 1", "sort code 12",
      "GB29 NWBK 6016 1331 9268 19", "40391877", "4111 1111 1111 1111",
      "About $4,000", "Saturday 2026-10-09", "a swift build", "1200 square feet", "two people, 8 hours"
    ].each do |text|
      it "agrees with PaymentDetailsCheck on #{text.inspect}" do
        expect(passes?(pay, %({"name": "#{text}"}))).to eq(PaymentDetailsCheck.clean?(text))
      end
    end
  end
end
