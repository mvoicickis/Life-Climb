# frozen_string_literal: true

class SitemapsController < ApplicationController
  allow_unauthenticated_access only: :show
  skip_onboarding_check

  def show
    @urls = PublicSitemap.urls
  end
end
