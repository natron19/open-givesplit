FactoryBot.define do
  factory :part do
    association :parts_plan
    sequence(:position) { |n| n }
    kind           { "hours" }
    name           { "Saturday build, 8 hours, two people" }
    quantity       { 16 }
    unit           { "hours" }
    why_it_matters { "Builds the beds in one day." }
  end
end
