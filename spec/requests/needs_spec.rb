require "rails_helper"

RSpec.describe "Needs", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:need)  { create(:need, user: user) }

  let(:valid_params) do
    { need: { need_text: "New benches and a grit bin for the bus shelter on Elm Row.", kinds: [ "", "materials", "hours" ],
              currency: "USD", rough_budget: "", community_context: "" } }
  end

  context "when not signed in" do
    it "redirects every page to sign in" do
      get needs_path
      expect(response).to redirect_to(sign_in_path)
      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
      post needs_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the dashboard as My needs with only the user's own needs" do
      create(:need, user: user, need_text: "Mine to split: a garden behind the laundromat.")
      create(:need, user: other, need_text: "Someone else's need: a new roof for the hall.")
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My needs", "Mine to split")
      expect(response.body).not_to include("Someone else&#39;s need")
    end

    it "shows the latest plan's name and counts on the dashboard" do
      create(:parts_plan, :completed, need: need)
      get needs_path
      expect(response.body).to include("Hall kitchen repair", "8 Parts", "6 not money")
    end

    it "shows an empty state with no needs" do
      get needs_path
      expect(response.body).to include("Describe your first need")
    end

    it "renders the new form with the labels the UI journey fills, all kinds ticked" do
      get new_need_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The need, in your own words", "Kinds of Part your community uses",
                                       "Currency", "Rough budget", "About your community", "Save need")
      Need::KIND_LABELS.each_value { |label| expect(response.body).to include(label) }
      expect(response.body.scan(/type="checkbox"[^>]*checked="checked"/).size).to eq(Need::KINDS.size)
    end

    it "creates a need with the ticked kinds and redirects to it" do
      expect { post needs_path, params: valid_params }.to change(user.needs, :count).by(1)
      expect(Need.last.kinds).to eq(%w[materials hours])
      expect(response).to redirect_to(need_path(Need.last))
    end

    it "re-renders the form with 422 on invalid input" do
      expect {
        post needs_path, params: { need: valid_params[:need].merge(need_text: "short") }
      }.not_to change(Need, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "refuses money as the only kind with 422" do
      post needs_path, params: { need: valid_params[:need].merge(kinds: [ "", "money" ]) }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("not money")
    end

    it "shows the need with the Split into parts button" do
      get need_path(need)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(need.need_text, "Split into parts", "Money never moves through this app")
    end

    it "updates a need, including unticking every kind but one" do
      patch need_path(need), params: { need: { kinds: [ "", "skill" ], rough_budget: "About $2,000" } }
      expect(response).to redirect_to(need_path(need))
      expect(need.reload.kinds).to eq(%w[skill])
      expect(need.rough_budget).to eq("About $2,000")
    end

    it "rejects an invalid update with 422" do
      patch need_path(need), params: { need: { currency: "BTC" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes a need" do
      need
      expect { delete need_path(need) }.to change(Need, :count).by(-1)
      expect(response).to redirect_to(needs_path)
    end
  end

  # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
  context "when signed in as a different user" do
    before { sign_in_as(other) }

    it "cannot see, edit, update, or delete the need" do
      get need_path(need)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
      get edit_need_path(need)
      expect(response).to redirect_to(root_path)
      patch need_path(need), params: { need: { rough_budget: "Hijacked" } }
      expect(response).to redirect_to(root_path)
      expect { delete need_path(need) }.not_to change(Need, :count)
      expect(response).to redirect_to(root_path)
      expect(need.reload.rough_budget).not_to eq("Hijacked")
    end
  end
end
