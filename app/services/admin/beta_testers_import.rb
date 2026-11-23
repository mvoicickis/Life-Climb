# frozen_string_literal: true

module Admin
  # Additive import of Play closed-test emails — never deletes or rewrites rows.
  class BetaTestersImport
    Result = Data.define(:added, :already_there, :no_account, :invalid)

    EMAIL_REGEXP = URI::MailTo::EMAIL_REGEXP

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text
    end

    def call
      counters = { added: 0, already_there: 0, no_account: 0, invalid: 0 }
      seen_valid = Set.new

      tokens(@text).each do |token|
        email = token.strip.downcase
        if email.blank?
          next
        elsif !email.match?(EMAIL_REGEXP)
          counters[:invalid] += 1
          next
        end

        next if seen_valid.include?(email)

        seen_valid << email
        user = User.find_by(email_address: email)
        counters[:no_account] += 1 if user.nil?

        existing = BetaTester.find_by(email: email)
        if existing
          counters[:already_there] += 1
          link_user!(existing, user)
        else
          BetaTester.create!(email: email, added_at: Time.current, user: user)
          counters[:added] += 1
        end
      end

      backfill_missing_user_ids!

      Result.new(**counters)
    end

    private

    def tokens(text)
      text.to_s.split(/[,;\s\n]+/)
    end

    def link_user!(beta_tester, user)
      return if user.blank?
      return if beta_tester.user_id.present?

      beta_tester.update!(user: user)
    end

    def backfill_missing_user_ids!
      BetaTester.where(user_id: nil).find_each do |beta_tester|
        user = User.find_by(email_address: beta_tester.email)
        next if user.nil?

        beta_tester.update!(user: user)
      end
    end
  end
end
