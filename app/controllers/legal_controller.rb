# frozen_string_literal: true

class LegalController < ApplicationController
  allow_unauthenticated_access
  skip_onboarding_check
  layout "landing"

  def privacy
    render_english_page("privacy")
  end

  def terms
    render_english_page("terms")
  end

  def delete_account
    render_english_page("delete_account")
  end

  def impressum
    render template: "legal/impressum"
  end

  private

  def render_english_page(name)
    render template: "legal/#{name}", formats: [ :html ], locales: [ :en ]
  end
end
