# frozen_string_literal: true

module PushOfferEndpoint
  extend ActiveSupport::Concern

  private

  def push_offer_eligible_for_win(win_number: nil)
    endpoint = params[:push_endpoint].to_s.strip
    endpoint = nil if endpoint.blank?

    current_user.push_offer_eligible?(win_number: win_number, endpoint: endpoint)
  end

  def push_offer_show_on_today_visit?
    push_offer_eligible_for_win &&
      Battles::WinsOnLocalDate.ever?(user: current_user) &&
      !flash[:push_offer_eligible].present?
  end
end
