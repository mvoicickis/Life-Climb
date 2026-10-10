# frozen_string_literal: true

module V2OnboardingIntegrationSessionHelper
  THREAD_KEY = :next_v2_onboarding_draft

  def get(path, *args, **kwargs)
    apply_staged_v2_onboarding_draft!(kwargs)
    super(path, *args, **kwargs)
  end

  def patch(path, *args, **kwargs)
    apply_staged_v2_onboarding_draft!(kwargs)
    super(path, *args, **kwargs)
  end

  def apply_staged_v2_onboarding_draft!(kwargs)
    draft = Thread.current[THREAD_KEY]
    return if draft.blank?

    Thread.current[THREAD_KEY] = nil
    env = (kwargs[:env] || {}).dup
    rack_session = (env["rack.session"] || {}).dup
    rack_session["v2_onboarding"] = draft
    env["rack.session"] = rack_session
    kwargs[:env] = env
  end
end

module StageV2OnboardingDraftForNextRequest
  def []=(key, value)
    super
    return unless key.to_s == "v2_onboarding" && value.is_a?(Hash)
    return if caller.any? { |line| line.include?("/app/controllers/") }

    Thread.current[V2OnboardingIntegrationSessionHelper::THREAD_KEY] =
      JSON.parse(JSON.generate(value.as_json))
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  prepend V2OnboardingIntegrationSessionHelper
end

ActionDispatch::Request::Session.prepend(StageV2OnboardingDraftForNextRequest)
