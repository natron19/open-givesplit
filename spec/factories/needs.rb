FactoryBot.define do
  factory :need do
    association :user
    need_text         { "The church hall kitchen needs two new burners, a sink that does not leak, and shelving put back on the wall." }
    kinds             { Need::KINDS }
    currency          { "USD" }
    rough_budget      { "Not sure, maybe $1,500" }
    community_context { "A congregation of about 200 households with several retired tradespeople." }
  end
end
