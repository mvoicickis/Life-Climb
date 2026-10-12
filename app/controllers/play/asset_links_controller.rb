# frozen_string_literal: true

module Play
  class AssetLinksController < ApplicationController
    allow_unauthenticated_access
    skip_onboarding_check

    def show
      render json: Play::AssetLinks.json, content_type: "application/json"
    end
  end
end
