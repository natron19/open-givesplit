class PartsPlan < ApplicationRecord
  belongs_to :need
  has_one :user, through: :need
  has_many :parts, -> { order(:position) }, dependent: :destroy, inverse_of: :parts_plan

  STATUSES = %w[pending completed failed].freeze

  # The code-enforced shape of a split (PartsPlansController#parse_plan!).
  PART_COUNT          = 8..14
  MAX_OWNER_QUESTIONS = 2

  CURRENCY_SYMBOLS = { "USD" => "$", "CAD" => "CA$", "GBP" => "£", "EUR" => "€", "AUD" => "A$", "NZD" => "NZ$" }.freeze

  validates :status, inclusion: { in: STATUSES }

  def completed? = status == "completed"
  def failed?    = status == "failed"

  # The need was edited after this plan ran.
  def stale?
    generated_at.present? && need.updated_at > generated_at
  end

  def money_parts     = parts.select(&:money?)
  def non_money_parts = parts.reject(&:money?)

  # The whole need as numbers, never a bar or a percentage (production's project header):
  # "$3,100 in money across 4 Parts, and 8 asks for time, tools, skills and materials."
  def numbers_sentence
    money     = money_parts
    non_money = non_money_parts
    priced    = money.select(&:amount)
    total     = priced.sum(&:amount)

    money_text =
      if money.empty?
        "No money"
      elsif priced.empty?
        "#{pluralize_parts(money.size)} in money, amounts left for you to set"
      else
        text = "#{self.class.format_money(total, need.currency)} in money across #{pluralize_parts(money.size)}"
        text += " (#{priced.size} with an amount)" if priced.size < money.size
        text
      end

    asks = non_money.size == 1 ? "1 ask" : "#{non_money.size} asks"
    "#{money_text}, and #{asks} for time, tools, skills and materials."
  end

  def to_markdown
    lines = []
    lines << "# #{project_name}"
    lines << ""
    lines << "_Split #{generated_at&.strftime('%Y-%m-%d') || 'at an unknown time'} by #{ENV.fetch('APP_NAME', 'Givesplit Demo')}. " \
             "AI-generated: a first draft of the Parts for you to edit. Amounts marked as a guess need checking. " \
             "Money never moves through this app._"
    lines << ""
    lines << description.to_s
    lines << ""
    lines << "**#{numbers_sentence}**"
    lines << ""
    lines << "## Parts"
    lines << ""
    parts.each_with_index do |part, i|
      size = part.size_label(need.currency)
      lines << "#{i + 1}. **#{part.name}** (#{part.kind_label}#{size ? ", #{size}" : ''})"
      lines << "   #{part.why_it_matters}" if part.why_it_matters.present?
    end
    lines << ""
    if questions_for_owner.any?
      lines << "## Questions for you"
      lines << ""
      questions_for_owner.each { |q| lines << "- #{q}" }
      lines << ""
    end
    lines << "## The need"
    lines << ""
    lines << need.need_text
    lines << ""
    lines << "_Kinds of Part used:_ #{need.kind_labels.join(', ')}"
    lines << "_Rough budget:_ #{need.rough_budget}" if need.rough_budget.present?
    lines.join("\n") + "\n"
  end

  def markdown_filename
    slug = project_name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "").presence || "need"
    "#{slug}-parts.md"
  end

  def self.format_money(amount, currency)
    symbol = CURRENCY_SYMBOLS.fetch(currency, "#{currency} ")
    "#{symbol}#{ActiveSupport::NumberHelper.number_to_delimited(format_number(amount))}"
  end

  def self.format_number(value)
    value.to_d == value.to_d.truncate ? value.to_i.to_s : value.to_d.round(2).to_s("F")
  end

  private

  def pluralize_parts(count) = count == 1 ? "1 Part" : "#{count} Parts"
end
