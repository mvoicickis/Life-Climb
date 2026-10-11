# frozen_string_literal: true

module Accounts
  class DestroyUser
    Result = Data.define(:ok?, :reason)

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      begin
        Billing::CancelSubscription.call(user: @user)
      rescue Stripe::StripeError => e
        Rails.logger.error("[accounts] destroy cancel failed user_id=#{@user.id}: #{e.message}")
        return Result.new(ok?: false, reason: :stripe)
      end

      @user.update_columns(focus_building_id: nil)
      @user.destroy!

      Result.new(ok?: true, reason: nil)
    end
  end
end
