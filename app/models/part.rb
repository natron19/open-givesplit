class Part < ApplicationRecord
  belongs_to :parts_plan

  validates :kind,     inclusion: { in: Need::KINDS }
  validates :name,     presence: true, length: { maximum: 120 }
  validates :position, presence: true
  validates :amount,   numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true

  def money? = kind == "money"

  def kind_label
    Need::KIND_LABELS.fetch(kind, kind.to_s.humanize)
  end

  # "About $900 (a guess; check a local price)", "16 hours", or nil.
  def size_label(currency)
    if money? && amount
      text = PartsPlan.format_money(amount, currency)
      price_is_guess ? "About #{text}, a guess to check" : text
    elsif !money? && quantity
      [ PartsPlan.format_number(quantity), unit.presence ].compact.join(" ")
    end
  end
end
