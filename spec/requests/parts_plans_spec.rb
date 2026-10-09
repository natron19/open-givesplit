require "rails_helper"

RSpec.describe "PartsPlans", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:need)  { create(:need, user: user) }

  def part(kind, name, extra = {})
    { "kind" => kind, "name" => name, "amount" => nil, "price_is_guess" => false, "quantity" => nil, "unit" => "",
      "why_it_matters" => "It is part of getting the kitchen working." }.merge(extra)
  end

  # 10 parts: 3 money, 7 not money.
  let(:parts) do
    [
      part("money",     "About $400 for two stove burners", "amount" => 400, "price_is_guess" => true),
      part("money",     "$180 for a new sink trap and hoses", "amount" => 180),
      part("money",     "A share of the gas fitter's call-out fee"),
      part("materials", "Six shelf brackets and wall plugs", "quantity" => 6, "unit" => "brackets"),
      part("tool_loan", "A cordless drill for one afternoon", "quantity" => 1, "unit" => "afternoon"),
      part("hours",     "Saturday clean-up, 4 hours, two people", "quantity" => 8, "unit" => "hours"),
      part("hours",     "Put the shelving back up, 3 hours, two people", "quantity" => 6, "unit" => "hours"),
      part("skill",     "A plumber's hour to fix the sink trap", "quantity" => 1, "unit" => "hours"),
      part("skill",     "A gas fitter's check of the stove", "quantity" => 1, "unit" => "hours"),
      part("materials", "A second fridge for the food bank shelf", "quantity" => 1, "unit" => "fridge")
    ]
  end

  let(:result) do
    {
      "project_name"        => "Hall kitchen repair",
      "description"         => "Fix the hall kitchen before the harvest supper.\n\nThe Parts cover the stove, the sink, the shelving and a second fridge.",
      "parts"               => parts,
      "questions_for_owner" => [ "Is the stove gas or electric?" ]
    }
  end

  def run_split
    post need_parts_plans_path(need)
  end

  describe "POST /needs/:need_id/splits" do
    context "when not signed in" do
      it "redirects to sign in" do
        run_split
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as the owner with a valid response" do
      before do
        sign_in_as(user)
        gemini_returns(result.to_json)
      end

      it "calls GeminiService with the template and the need's variables" do
        expect(GeminiService).to receive(:generate).with(
          template:  "givesplit_parts_v1",
          variables: {
            need_text:         need.need_text,
            enabled_kinds:     "money, materials, tool_loan, hours, skill",
            currency:          "USD",
            rough_budget:      need.rough_budget,
            community_context: need.community_context
          }
        ).and_return(result.to_json)
        run_split
      end

      it "creates a completed plan with its parts in order and the raw response" do
        expect { run_split }.to change(PartsPlan, :count).by(1).and change(Part, :count).by(10)
        plan = PartsPlan.last
        expect(plan.status).to eq("completed")
        expect(plan.gemini_raw).to eq(result.to_json)
        expect(plan.project_name).to eq("Hall kitchen repair")
        expect(plan.questions_for_owner).to eq([ "Is the stove gas or electric?" ])
        expect(plan.parts.map(&:name)).to eq(parts.map { |p| p["name"] })
        expect(plan.parts.first).to have_attributes(kind: "money", amount: 400, price_is_guess: true)
        expect(plan.parts.find_by(kind: "tool_loan")).to have_attributes(quantity: 1, unit: "afternoon")
        expect(plan.generated_at).to be_present
      end

      it "redirects to the result page" do
        run_split
        expect(response).to redirect_to(need_parts_plan_path(need, PartsPlan.last))
      end

      it "accepts a response wrapped in a ```json fence and without questions_for_owner" do
        gemini_returns("```json\n#{result.except('questions_for_owner').to_json}\n```")
        run_split
        expect(PartsPlan.last).to have_attributes(status: "completed", questions_for_owner: [])
      end

      it "accepts exactly half the parts as money" do
        mixed = parts.first(3) + [ part("money", "About $90 for paint", "amount" => 90, "price_is_guess" => true),
                                   part("money", "About $60 for filler", "amount" => 60, "price_is_guess" => true) ] + parts.last(5)
        gemini_returns(result.merge("parts" => mixed).to_json)
        run_split
        expect(PartsPlan.last.status).to eq("completed")
      end

      it "drops an amount on a non-money part and a quantity on a money part, as production does" do
        tweaked = parts.dup
        tweaked[0] = tweaked[0].merge("quantity" => 2, "unit" => "burners")
        tweaked[5] = tweaked[5].merge("amount" => 50, "price_is_guess" => true)
        gemini_returns(result.merge("parts" => tweaked).to_json)
        run_split
        plan = PartsPlan.last
        expect(plan.parts.first).to have_attributes(quantity: nil, unit: nil, amount: 400)
        expect(plan.parts.find_by(position: 6)).to have_attributes(amount: nil, price_is_guess: false, quantity: 8)
      end

      it "parses the seeded Ashgrove example, so the demo data obeys the same rules" do
        expect { Rails.application.load_seed }.to output.to_stdout
        example = User.find_by!(email: "demo@example.com").needs.first
        gemini_returns(example.parts_plans.first.gemini_raw)
        sign_in_as(example.user)
        post need_parts_plans_path(example)
        expect(example.parts_plans.order(:created_at).last.status).to eq("completed")
      end
    end

    context "when the response cannot be used" do
      before { sign_in_as(user) }

      def expect_failed(text, reason)
        gemini_returns(text)
        expect { run_split }.to change(PartsPlan, :count).by(1).and change(Part, :count).by(0)
        plan = PartsPlan.last
        expect(plan.status).to eq("failed")
        expect(plan.gemini_raw).to eq(text)
        expect(plan.failure_reason).to include(reason)
        expect(response).to redirect_to(need_parts_plan_path(need, plan))
      end

      it("fails text that is not JSON")       { expect_failed("this is not json at all", "JSON parse failed") }
      it("fails a JSON array")                { expect_failed("[1, 2]", "Expected a JSON object") }
      it("fails a missing project_name")      { expect_failed(result.except("project_name").to_json, "project_name") }
      it("fails a blank description")         { expect_failed(result.merge("description" => " ").to_json, "description") }
      it("fails three questions_for_owner")   { expect_failed(result.merge("questions_for_owner" => %w[A? B? C?]).to_json, "questions_for_owner") }
      it("fails a part without why_it_matters") { expect_failed(result.merge("parts" => parts.each_with_index.map { |p, i| i.zero? ? p.except("why_it_matters") : p }).to_json, "Part 1 has no why_it_matters") }
      it("fails an unknown kind")             { expect_failed(result.merge("parts" => parts.first(9) + [ part("favour", "A favour") ]).to_json, "unknown kind") }
      it("fails a string amount")             { expect_failed(result.merge("parts" => [ part("money", "Lumber", "amount" => "$900") ] + parts.drop(1)).to_json, "amount that is not a number") }
      it("fails a non-boolean price_is_guess") { expect_failed(result.merge("parts" => [ parts[0].merge("price_is_guess" => "yes") ] + parts.drop(1)).to_json, "price_is_guess") }

      # Hard rule: 8 to 14 Parts (production: "eight to fourteen").
      it "fails 7 parts" do
        expect_failed(result.merge("parts" => parts.first(7)).to_json, "Expected 8-14 parts, got 7")
      end

      it "fails 15 parts" do
        expect_failed(result.merge("parts" => parts + parts.last(5)).to_json, "Expected 8-14 parts, got 15")
      end

      # Hard rule: only the kinds the member enabled.
      it "fails a part whose kind the member did not enable" do
        need.update!(kinds: %w[money materials hours skill])
        expect_failed(result.to_json, "uses a kind you did not enable (tool_loan)")
      end

      # Hard rule: at least half the Parts are not money.
      it "fails when fewer than half the parts are not money" do
        money_heavy = parts.first(3) + Array.new(3) { |i| part("money", "Cash part #{i}", "amount" => 500) } + parts.last(4)
        expect_failed(result.merge("parts" => money_heavy).to_json, "Only 4 of 10 parts are not money")
      end

      # Hard rule: no payment details anywhere (PaymentDetailsCheck).
      {
        "a payment link"   => { "name" => "Pledge at paypal.me/ashgrovegarden" },
        "an account number" => { "why_it_matters" => "Send it to account 40391877." },
        "a platform"       => { "name" => "Set up a GoFundMe page" }
      }.each do |what, change|
        it "fails a plan with #{what} in a part" do
          expect_failed(result.merge("parts" => [ parts[0].merge(change) ] + parts.drop(1)).to_json, "payment details")
        end
      end

      it "fails a plan that smuggles a link in an extra key" do
        expect_failed(result.merge("giving_link" => "https://example.org/give").to_json, "payment details")
      end

      it "shows the reason, Retry, and the raw response on the result page, with no download" do
        gemini_returns(result.merge("parts" => [ parts[0].merge("name" => "Pledge at paypal.me/ashgrovegarden") ] + parts.drop(1)).to_json)
        run_split
        follow_redirect!
        expect(response.body).to include("could not be used", "payment details", "Money never moves through this app",
                                         "Retry", "paypal.me/ashgrovegarden")
        expect(response.body).not_to include("Download .md")
      end
    end

    context "when GeminiService raises" do
      before { sign_in_as(user) }

      {
        GeminiService::BudgetExceededError => "daily AI request limit",
        GeminiService::GatekeeperError     => "couldn't be processed",
        GeminiService::OutputGuardError    => "didn't pass our safety checks",
        GeminiService::TimeoutError        => "took too long",
        GeminiService::GeminiError         => "An unexpected error occurred"
      }.each do |error_class, message|
        it "renders the #{error_class.name.demodulize} message with 422 and creates no plan" do
          gemini_raises(error_class)
          expect { run_split }.not_to change(PartsPlan, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include(message, "Try again")
        end
      end
    end

    # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
    context "when signed in as a different user" do
      it "does not find the need, calls no AI, and creates no plan" do
        sign_in_as(other)
        expect(GeminiService).not_to receive(:generate)
        expect { run_split }.not_to change(PartsPlan, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("That record could not be found.")
      end
    end

    context "rate limit" do
      it "refuses the 11th split within a minute" do
        sign_in_as(user)
        gemini_returns(result.to_json)
        10.times { run_split }
        expect(response).to have_http_status(:redirect)
        run_split
        expect(response).to have_http_status(:too_many_requests)
        expect(PartsPlan.count).to eq(10)
      end
    end
  end

  describe "GET /needs/:need_id/splits (the error page's Try again)" do
    it "redirects to the need" do
      sign_in_as(user)
      get need_parts_plans_path(need)
      expect(response).to redirect_to(need_path(need))
    end
  end

  describe "GET /needs/:need_id/splits/:id" do
    context "for a completed plan" do
      let(:plan) { create(:parts_plan, :completed, need: need, generated_at: 1.minute.from_now) }

      it "shows the name, numbers, part tiles, questions, actions, and disclaimer" do
        sign_in_as(user)
        get need_parts_plan_path(need, plan)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          "Hall kitchen repair", "Fix the hall kitchen", plan.numbers_sentence, "8 Parts",
          "About $400 for two stove burners", "About $400, a guess to check", "A cordless drill for one afternoon",
          "Tool loans", "Questions for you", "Is the stove gas or electric?",
          "Download .md", "Show raw response", "AI-generated.", "Money never moves through this app"
        )
        expect(response.body).not_to include("Your need has changed", "%")
      end
    end

    context "for a failed plan" do
      it "shows the reason, Retry, and the raw response, with no download" do
        plan = create(:parts_plan, :failed, need: need)
        sign_in_as(user)
        get need_parts_plan_path(need, plan)
        expect(response.body).to include("could not be used", plan.failure_reason, "Retry", "malformed response")
        expect(response.body).not_to include("Download .md")
      end
    end

    it "warns when the need changed after the plan" do
      plan = create(:parts_plan, :completed, need: need, generated_at: 1.hour.ago)
      need.update!(rough_budget: "About $2,000")
      sign_in_as(user)
      get need_parts_plan_path(need, plan)
      expect(response.body).to include("Your need has changed since this split")
    end

    it "does not show another user's plan" do
      plan = create(:parts_plan, :completed, need: need)
      sign_in_as(other)
      get need_parts_plan_path(need, plan)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
    end

    it "does not show a plan under a different need of the same user" do
      plan = create(:parts_plan, :completed, need: need)
      sign_in_as(user)
      get need_parts_plan_path(create(:need, user: user), plan)
      expect(response).to redirect_to(root_path)
    end
  end
end
