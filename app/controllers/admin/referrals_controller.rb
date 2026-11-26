# frozen_string_literal: true

module Admin
  class ReferralsController < BaseController
    def index
      @roster = ReferralsRoster.call
      @admin_referral_url = admin_referral_link_for(current_user)
    end
  end
end