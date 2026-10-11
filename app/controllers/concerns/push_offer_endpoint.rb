# frozen_string_literal: true

module PushOfferEndpoint
  extend ActiveSupport::Concern

  private

  def push_offer_eligible_for_win(win_number: nil)
    endpoint = params[:push_endpoint].to_s.strip
    endpoint = nil if endpoint.blank?

    current_user.push_offer_eligible?(win_number: win_number, endpoint: endpoint)
  end

  def push_offer_won_battle_today?
    local_date = Battles::WinsOnLocalDate.local_today_for(current_user)
    time_zone = Battles::WinsOnLocalDate.time_zone_for(current_user)
    Battles::WinsOnLocalDate.count_for_date(
      user: current_user,
      date: local_date,
      time_zone: time_zone
    ).positive?
  end

  def push_offer_show_on_today_visit?
    push_offer_eligible_for_win &&
      push_offer_won_battle_today? &&
      !flash[:push_offer_eligible].present?
  end
end
