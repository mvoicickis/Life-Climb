# frozen_string_literal: true

class IntegrationV2OnboardingSessionOverlay
  THREAD_KEY = :integration_v2_onboarding_draft

  def self.stage!(draft)
    Thread.current[THREAD_KEY] = draft
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    if (draft = Thread.current[THREAD_KEY])
      Thread.current[THREAD_KEY] = nil
      ActionDispatch::Request.new(env).session[:v2_onboarding] = draft
    end

    @app.call(env)
  end
end
