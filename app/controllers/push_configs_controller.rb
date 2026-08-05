# frozen_string_literal: true

class PushConfigsController < ApplicationController
  def show
    render json: {
      publicKey: VapidConfig.public_key,
      enabled: VapidConfig.configured?
    }
  end
end
