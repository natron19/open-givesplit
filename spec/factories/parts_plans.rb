FactoryBot.define do
  factory :parts_plan do
    association :need
    status       { "pending" }
    generated_at { nil }
    gemini_raw   { nil }

    trait :completed do
      status              { "completed" }
      generated_at        { Time.current }
      gemini_raw          { "{}" }
      project_name        { "Hall kitchen repair" }
      description         { "Fix the hall kitchen before the harvest supper.\n\nThe Parts cover the stove, the sink and the shelving." }
      questions_for_owner { [ "Is the stove gas or electric?" ] }

      after(:create) do |plan|
        [
          { kind: "money",     name: "About $400 for two stove burners", amount: 400, price_is_guess: true },
          { kind: "money",     name: "A share of the plumber's parts", amount: nil },
          { kind: "materials", name: "Six shelf brackets and wall plugs", quantity: 6, unit: "brackets" },
          { kind: "tool_loan", name: "A cordless drill for one afternoon", quantity: 1, unit: "afternoon" },
          { kind: "hours",     name: "Saturday clean-up, 4 hours, two people", quantity: 8, unit: "hours" },
          { kind: "skill",     name: "A plumber's hour to fix the sink trap", quantity: 1, unit: "hours" },
          { kind: "skill",     name: "A gas fitter's check of the stove", quantity: 1, unit: "hours" },
          { kind: "hours",     name: "Put the shelving back up, 3 hours, two people", quantity: 6, unit: "hours" }
        ].each_with_index do |attrs, i|
          plan.parts.create!(attrs.merge(position: i + 1, why_it_matters: "Part of getting the kitchen working."))
        end
        plan.parts.reset
      end
    end

    trait :failed do
      status         { "failed" }
      generated_at   { Time.current }
      gemini_raw     { "malformed response" }
      failure_reason { "JSON parse failed: unexpected token" }
    end
  end
end
