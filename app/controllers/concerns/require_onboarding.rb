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
    return unless current_user&.needs_onboarding?

    if current_user.planning_v2? || current_user.dreams.none?
      # New users without dreams go to calm v2 onboarding; legacy mid-flow keeps old path.
      redirect_to(current_user.dreams.any? && !current_user.planning_v2? ? onboarding_path : v2_onboarding_path)
    end
  end
end
