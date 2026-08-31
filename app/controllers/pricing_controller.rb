# frozen_string_literal: true

class PricingController < ApplicationController
  def show
    case params[:billing]
    when "success"
      flash.now[:notice] = t("pricing.checkout_success")
    when "cancel"
      flash.now[:notice] = t("pricing.checkout_cancel")
    end
  end
end
