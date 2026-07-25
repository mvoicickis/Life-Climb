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
    return if %w[onboarding sessions registrations passwords].include?(controller_name)
    return unless current_user&.needs_onboarding?

    redirect_to onboarding_path
  end
end
