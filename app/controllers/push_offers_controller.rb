# frozen_string_literal: true

class PushOffersController < ApplicationController
  def destroy
    current_user.mark_push_offer_dismissed!
    current_user.mark_push_offer_shown!
    head :no_content
  end

  def update
    current_user.mark_push_offer_permission_denied!
    current_user.mark_push_offer_shown!
    head :no_content
  end

  def shown
    current_user.mark_push_offer_shown!
    head :no_content
  end
end
