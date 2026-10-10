# frozen_string_literal: true

# Applies a v2 onboarding draft staged by integration tests onto rack.session before
# the app runs (see test/test_helper.rb).
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
      rack_session = env["rack.session"] ||= {}
      rack_session["v2_onboarding"] = draft
    end

    @app.call(env)
  end
end
