module RequireOnboarding
  extend ActiveSupport::Concern

  included do
    before_action :redirect_to_onboarding_if_needed
  end

  class_methods do
    def skip_onboarding_check(**options)
      skip_before_action :redirect_to_onboarding_if_needed, **options
    end
  end

  private

  def redirect_to_onboarding_if_needed
    return unless authenticated?
    return if %w[onboarding sessions registrations passwords v2_onboardings life_area_selections next_mountains].include?(controller_name)

    current_user.update!(planning_version: 2) if current_user && !current_user.planning_v2?
    if current_user&.needs_onboarding?
      redirect_to v2_onboarding_path and return
    end

    return unless current_user&.needs_adventure_guide?

    redirect_to v2_onboarding_path(step: "how")
  end
end
