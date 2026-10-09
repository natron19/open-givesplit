class Need < ApplicationRecord
  belongs_to :user
  has_many :parts_plans, dependent: :destroy
  has_one :latest_parts_plan,
          -> { order(generated_at: :desc, created_at: :desc) },
          class_name: "PartsPlan"

  # The five kinds of Part, in production Givesplit's order. A Part is one named, claimable piece of the need.
  KINDS = %w[money materials tool_loan hours skill].freeze
  NON_MONEY_KINDS = (KINDS - %w[money]).freeze

  KIND_LABELS = {
    "money"     => "Money",
    "materials" => "Materials",
    "tool_loan" => "Tool loans",
    "hours"     => "Hours",
    "skill"     => "Skills"
  }.freeze

  # One-line explanation per kind, shown under each checkbox. The system prompt explains the kinds to the model.
  KIND_HINTS = {
    "money"     => "an amount someone gives directly to the owner",
    "materials" => "things to buy or hand over: soil, lumber, paint, chairs",
    "tool_loan" => "something lent and returned: a rototiller for a weekend, a van for a day",
    "hours"     => "time: two people for a Saturday, an evening a week",
    "skill"     => "a skill someone brings: an electrician's afternoon, a plan drawn up"
  }.freeze

  CURRENCIES = %w[USD CAD GBP EUR AUD NZD].freeze

  NEED_TEXT_RANGE = 20..1500 # production caps the owner's sentences at 1,500 characters

  validates :need_text,         presence: true, length: { in: NEED_TEXT_RANGE }
  validates :currency,          inclusion: { in: CURRENCIES }
  validates :community_context, length: { maximum: 1000 }
  validates :rough_budget,      length: { maximum: 200 }
  validate  :kinds_are_known_and_not_money_only

  before_validation :normalize_kinds

  def kind_labels
    kinds.map { |k| KIND_LABELS.fetch(k, k.humanize) }
  end

  # A short heading for lists: the latest plan's project name, or the start of the need.
  def heading
    latest_parts_plan&.project_name.presence || need_text.to_s.squish.truncate(80)
  end

  # Variables for the givesplit_parts_v1 template. Nothing about the user is sent.
  def ai_variables
    {
      need_text:         need_text,
      enabled_kinds:     kinds.join(", "),
      currency:          currency,
      rough_budget:      rough_budget.presence || "Not stated",
      community_context: community_context.presence || "Not stated"
    }
  end

  private

  # Checkbox groups submit a blank first value. Known kinds keep KINDS order; unknown ones stay so the
  # validation can name them.
  def normalize_kinds
    given = Array(kinds).map(&:to_s).reject(&:blank?).uniq
    self.kinds = (KINDS & given) + (given - KINDS)
  end

  def kinds_are_known_and_not_money_only
    unknown = kinds - KINDS
    if kinds.empty?
      errors.add(:kinds, "must include at least one kind of Part")
    elsif unknown.any?
      errors.add(:kinds, "include an unknown kind: #{unknown.join(', ')}")
    elsif (kinds & NON_MONEY_KINDS).empty?
      errors.add(:kinds, "must include at least one kind that is not money (at least half the Parts cost nothing but time, a tool, a skill, or materials)")
    end
  end
end
