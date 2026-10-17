# frozen_string_literal: true

class PushOffersController < ApplicationController
  def destroy
    current_user.mark_push_offer_dismissed!
    current_user.mark_push_offer_shown!
    head :no_content
  end

  def update
    count_show_day = push_offer_count_show_day_param
    current_user.mark_push_offer_permission_denied!
    current_user.mark_push_offer_shown!(count_show_day: count_show_day)
    head :no_content
  end

  def shown
    current_user.mark_push_offer_shown!(count_show_day: push_offer_count_show_day_param)
    head :no_content
  end

  private

  def push_offer_count_show_day_param
    ActiveModel::Type::Boolean.new.cast(params.fetch(:count_show_day, true))
  end
end
