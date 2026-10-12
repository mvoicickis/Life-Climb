# frozen_string_literal: true

class PricingController < ApplicationController
  before_action :redirect_if_play_app!, only: :show

  def show
    case params[:billing]
    when "success"
      flash.now[:notice] = t("pricing.checkout_success")
    when "cancel"
      flash.now[:notice] = t("pricing.checkout_cancel")
    end
  end
end
