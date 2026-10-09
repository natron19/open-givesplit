class PartsPlansController < ApplicationController
  TEMPLATE = "givesplit_parts_v1".freeze

  before_action :set_need

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }

  # shared/_ai_error's "Try again" button is a GET to the current path; send it back to the need.
  def index
    redirect_to need_path(@need)
  end

  def show
    @parts_plan = @need.parts_plans.find(params[:id])
  end

  def create
    raw = GeminiService.generate(template: TEMPLATE, variables: @need.ai_variables)

    @parts_plan = @need.parts_plans.create!(
      status:       "pending",
      gemini_raw:   raw,
      generated_at: Time.current
    )

    result = parse_plan!(raw)
    PartsPlan.transaction do
      result[:parts].each_with_index { |attrs, i| @parts_plan.parts.create!(attrs.merge(position: i + 1)) }
      @parts_plan.update!(result.except(:parts).merge(status: "completed"))
    end
    redirect_to need_parts_plan_path(@need, @parts_plan)

  rescue ParseError => e
    @parts_plan.update!(status: "failed", failure_reason: e.message.truncate(250), gemini_raw: e.raw)
    redirect_to need_parts_plan_path(@need, @parts_plan)

  rescue GeminiService::BudgetExceededError
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity

  rescue GeminiService::GatekeeperError
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity

  rescue GeminiService::OutputGuardError
    render "shared/ai_error_page", locals: { error_type: :output_blocked }, status: :unprocessable_entity

  rescue GeminiService::TimeoutError
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity

  rescue GeminiService::GeminiError
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  private

  def set_need
    @need = current_user.needs.find(params[:need_id])
  end

  ParseError = Class.new(StandardError) do
    attr_reader :raw
    def initialize(msg, raw:)
      super(msg)
      @raw = raw
    end
  end

  # Validates the givesplit_parts_v1 JSON and returns the PartsPlan attributes plus a :parts list.
  # Hard rules enforced here, not trusted to the model:
  #   - 8 to 14 Parts;
  #   - every Part uses a kind the member enabled;
  #   - at least half the Parts are not money;
  #   - no payment details anywhere in the output (PaymentDetailsCheck).
  # As in production's ProjectSplitService, an amount on a non-money Part and a quantity on a money Part are dropped.
  def parse_plan!(raw)
    fail_parse = ->(msg) { raise ParseError.new(msg, raw: raw) }

    stripped = raw.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    parsed   = JSON.parse(stripped)
    fail_parse.("Expected a JSON object") unless parsed.is_a?(Hash)

    name = parsed["project_name"]
    fail_parse.("project_name is missing") unless name.is_a?(String) && name.strip.present?

    description = parsed["description"]
    fail_parse.("description is missing") unless description.is_a?(String) && description.strip.present?

    questions = parsed.fetch("questions_for_owner", [])
    unless questions.is_a?(Array) && questions.size <= PartsPlan::MAX_OWNER_QUESTIONS && questions.all? { |q| q.is_a?(String) && q.strip.present? }
      fail_parse.("Expected 0-#{PartsPlan::MAX_OWNER_QUESTIONS} questions_for_owner")
    end

    parts = parsed["parts"]
    fail_parse.("parts must be a list") unless parts.is_a?(Array)
    unless PartsPlan::PART_COUNT.cover?(parts.size)
      fail_parse.("Expected #{PartsPlan::PART_COUNT.min}-#{PartsPlan::PART_COUNT.max} parts, got #{parts.size}")
    end
    parts = parts.each_with_index.map { |part, i| parse_part!(part, i + 1, fail_parse) }

    non_money = parts.count { |p| p[:kind] != "money" }
    if non_money * 2 < parts.size
      fail_parse.("Only #{non_money} of #{parts.size} parts are not money; at least half must cost nothing but time, a tool, a skill or materials")
    end

    # The whole response, not only the fields kept: an extra key must not smuggle in a payment link.
    payment = PaymentDetailsCheck.found_in(stripped)
    if payment.any?
      fail_parse.("The response included payment details (#{payment.join(', ')}), so it was not shown. Money never moves through this app")
    end

    {
      project_name:        name.strip.truncate(120),
      description:         description.strip,
      questions_for_owner: questions.map(&:strip),
      parts:               parts
    }
  rescue JSON::ParserError => e
    raise ParseError.new("JSON parse failed: #{e.message.truncate(120)}", raw: raw)
  end

  def parse_part!(part, number, fail_parse)
    fail_parse.("Part #{number} is not an object") unless part.is_a?(Hash)

    kind = part["kind"].to_s
    fail_parse.("Part #{number} has an unknown kind #{kind.inspect}") unless Need::KINDS.include?(kind)
    fail_parse.("Part #{number} uses a kind you did not enable (#{kind})") unless @need.kinds.include?(kind)

    name = part["name"]
    fail_parse.("Part #{number} has no name") unless name.is_a?(String) && name.strip.present?

    why = part["why_it_matters"]
    fail_parse.("Part #{number} has no why_it_matters") unless why.is_a?(String) && why.strip.present?

    amount   = part["amount"]
    quantity = part["quantity"]
    fail_parse.("Part #{number} has an amount that is not a number") unless amount.nil? || (amount.is_a?(Numeric) && amount >= 0)
    fail_parse.("Part #{number} has a quantity that is not a number") unless quantity.nil? || (quantity.is_a?(Numeric) && quantity.positive?)

    guess = part.fetch("price_is_guess", false)
    fail_parse.("Part #{number} price_is_guess must be true or false") unless [ true, false ].include?(guess)

    unit = part["unit"]
    fail_parse.("Part #{number} unit must be a string") unless unit.nil? || unit.is_a?(String)

    money = kind == "money"
    {
      kind:           kind,
      name:           name.strip.truncate(120),
      amount:         money ? amount : nil,
      price_is_guess: money && !amount.nil? && guess,
      quantity:       money ? nil : quantity,
      unit:           money ? nil : unit.to_s.strip.presence,
      why_it_matters: why.strip
    }
  end
end
