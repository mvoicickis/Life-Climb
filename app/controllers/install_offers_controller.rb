# frozen_string_literal: true

class InstallOffersController < ApplicationController
  def destroy
    current_user.mark_install_offer_dismissed!
    head :no_content
  end

  def update
    current_user.mark_install_offer_installed!
    head :no_content
  end
end
