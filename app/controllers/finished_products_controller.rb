class FinishedProductsController < ApplicationController
  def index
    @products = current_user.finished_products.newest_first
  end

  def show
    @product = current_user.finished_products.find(params[:id])
    @support_moment = offer_support_moment!
  end

  private

  def offer_support_moment!
    moment = SupportMoment.new(current_user)
    key = moment.eligible
    moment.mark_shown!(key) if key
    key
  end
end
