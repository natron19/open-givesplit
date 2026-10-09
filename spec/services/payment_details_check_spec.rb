require "rails_helper"

RSpec.describe PaymentDetailsCheck do
  describe ".found_in" do
    {
      "Pledge at paypal.me/ashgrovegarden"                => "a link",
      "Details at https://example.org/give"               => "a link",
      "See www.ashgrove.example for the plan"             => "a link",
      "Send it by Venmo to the treasurer"                 => "a payment platform",
      "Set up a GoFundMe page for strangers"              => "a payment platform",
      "Cash App the coach"                                => "a payment platform",
      "Our account number is with the treasurer"          => "bank details",
      "Use routing number and sort code"                  => "bank details",
      "Pay to IBAN on request"                            => "bank details",
      "GB29 NWBK 6016 1331 9268 19"                       => "an IBAN",
      "Transfer to 40391877"                              => "an account or card number",
      "Send it to account 40391877."                      => "an account or card number",
      "Card 4111 1111 1111 1111"                          => "an account or card number"
    }.each do |text, label|
      it "finds #{label} in #{text.inspect}" do
        expect(described_class.found_in(text)).to include(label)
      end
    end

    [
      "About $4,000 for the whole garden",
      "About $900 for cedar lumber; check a local price",
      "CA$1,200 for a used deck oven",
      "Saturday build on 2026-10-09, 8 hours, two people",
      "A swift build day with four people",
      "Sort out the shed and the account of what was planted",
      "12 cubic yards of soil, 1200 square feet of beds",
      "A grant of 12345678.50 for the hall roof",
      "Money is arranged privately between people"
    ].each do |text|
      it "passes ordinary plan text: #{text.inspect}" do
        expect(described_class.found_in(text)).to be_empty
        expect(described_class.clean?(text)).to be(true)
      end
    end
  end
end
