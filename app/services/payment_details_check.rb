# Code-side guard on AI output (not trusted to the model): a parts plan never carries payment details.
#
# Production Givesplit's rule is that money never moves through the app. A pledge reveals the owner's private
# Giving Instructions, and the splitter must never propose "any payment link, account number, or instruction to
# send money through a platform". The demo has no Giving Instructions at all, so any of these in the output
# fails the plan, even when the member typed it into the need:
#
#   - a link (http://, https://, www., or a bare domain such as paypal.me/garden);
#   - a payment or crowdfunding platform by name (PayPal, Venmo, Zelle, Cash App, GoFundMe, ...);
#   - bank details by name (account number, routing number, sort code, IBAN, SWIFT/BIC);
#   - an IBAN-shaped code, 8 or more digits in a row, or card-style groups of four ("4111 1111 1111").
#
# Amounts ("$4,000", "1200"), dates ("2026-10-09") and ordinary words ("a swift build") never match. It errs
# toward blocking; a blocked plan shows the member a plain reason and a Retry button.
#
# evals/cases/givesplit_parts_v1.yml mirrors PATTERNS in one `matches` check; spec/services/
# payment_details_check_spec.rb keeps the two in step.
class PaymentDetailsCheck
  PATTERNS = {
    "a link"                    => %r{\bhttps?://|\bwww\.|\b[a-z0-9-]+\.(?:com|org|net|me|io|co|app|link|ly)/}i,
    "a payment platform"        => /\b(?:paypal|venmo|zelle|cash\s?app|gofundme|go\s?fund\s?me|givebutter|donorbox|patreon|kickstarter|indiegogo|ko-?fi|buy\s?me\s?a\s?coffee)\b/i,
    "bank details"              => /\b(?:account\s+(?:number|no\b|#)|routing\s+(?:number|no\b)|sort\s+code|iban\b|swift\s+code|swift\/bic|bic\s+code|bsb\s+(?:number|code))/i,
    "an IBAN"                   => /\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]{4}){3,7}\b/,
    "an account or card number" => /(?<![\d.,])(?:\d{8,}|\d{4}(?:[ -]\d{4}){2,})(?!\d|[.,]\d)/
  }.freeze

  # Labels of the patterns found in `text` (empty when the text is clean).
  def self.found_in(text)
    PATTERNS.select { |_label, pattern| text.to_s.match?(pattern) }.keys
  end

  def self.clean?(text)
    found_in(text).empty?
  end
end
