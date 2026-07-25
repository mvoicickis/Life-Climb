class FinishedProductsController < ApplicationController
  def index
    @products = current_user.finished_products.newest_first
  end

  def show
    @product = current_user.finished_products.find(params[:id])
  end
end
