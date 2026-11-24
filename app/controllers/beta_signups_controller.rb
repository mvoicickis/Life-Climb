# frozen_string_literal: true

class BetaSignupsController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_onboarding_check only: :create

  # Delegate so rate_limit uses Rails.cache at request time (test can swap to MemoryStore).
  RATE_LIMIT_CACHE = Object.new.tap do |store|
    store.define_singleton_method(:increment) do |key, amount, expires_in:|
      Rails.cache.increment(key, amount, expires_in: expires_in)
    end
  end

  rate_limit to: 5, within: 1.minute, only: :create, with: -> { rate_limited_response }, store: RATE_LIMIT_CACHE

  def create
    if honeypot_filled?
      respond_with_success
      return
    end

    email = beta_signup_params[:email].to_s.strip
    @source_path = safe_source_path

    if existing_signup?(email)
      respond_with_success
      return
    end

    @signup = BetaSignup.new(
      email: email,
      source_path: @source_path,
      user_agent: request.user_agent.to_s.truncate(512)
    )

    if @signup.save
      respond_with_success
    else
      respond_with_error
    end
  end

  private

  def beta_signup_params
    params.fetch(:beta_signup, {}).permit(:email, :source_path, :company)
  end

  def honeypot_filled?
    beta_signup_params[:company].present?
  end

  def existing_signup?(email)
    normalized = email.to_s.strip.downcase
    return false if normalized.blank?

    BetaSignup.exists?(email: normalized)
  end

  def safe_source_path
    path = beta_signup_params[:source_path].to_s
    return "/" unless path.start_with?("/") && !path.start_with?("//")

    path
  end

  def success_message
    t("beta_card.success_title")
  end

  def respond_with_success
    @success = true

    respond_to do |format|
      format.turbo_stream { render :create, status: :ok }
      format.html { redirect_back_or_source notice: success_message }
    end
  end

  def respond_with_error
    @success = false

    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back_or_source alert: @signup.errors.full_messages_for(:email).first || t("beta_card.email_invalid")
      end
    end
  end

  def rate_limited_response
    message = t("beta_card.rate_limited")

    respond_to do |format|
      format.turbo_stream do
        redirect_back fallback_location: root_path, alert: message, status: :see_other
      end
      format.html { redirect_back fallback_location: root_path, alert: message }
    end
  end

  def redirect_back_or_source(**flash_hash)
    fallback = @source_path.presence || root_path
    redirect_back fallback_location: fallback, allow_other_host: false, **flash_hash
  end
end
