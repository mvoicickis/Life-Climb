# frozen_string_literal: true

class NotificationTimeZonesController < ApplicationController
  def update
    Notifications::EnsureTimeZone.call(user: current_user, zone: params[:time_zone])
    head :no_content
  end
end
