# frozen_string_literal: true

# Integration tests sometimes merge into session[:v2_onboarding]; coerce to a plain
# Hash before the next request so nested camp_titles survive rack-test serialization.
module V2OnboardingSessionHelper
  def get(path, *args, **kwargs)
    coerce_v2_onboarding_session!
    super(path, *args, **kwargs)
  end

  def patch(path, *args, **kwargs)
    coerce_v2_onboarding_session!
    super(path, *args, **kwargs)
  end

  def coerce_v2_onboarding_session!
    return if @request.nil?

    draft = session[:v2_onboarding]
    return unless draft.is_a?(Hash) && draft.present?

    session[:v2_onboarding] = JSON.parse(JSON.generate(draft.as_json))
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  prepend V2OnboardingSessionHelper
end
