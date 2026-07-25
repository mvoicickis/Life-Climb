class SupportsController < ApplicationController
  def show
    @providers = SupportProviders.enabled
    @coming_soon = SupportProviders.coming_soon
    @primary = SupportProviders.primary
  end

  def dismiss_moment
    moment = SupportMoment.new(current_user)
    if params[:mute].present?
      moment.mute!
    elsif params[:milestone].present?
      key = params[:milestone].to_s
      if SupportMoment::MILESTONES.map(&:to_s).include?(key)
        moment.mark_shown!(key)
      end
    end

    redirect_back fallback_location: support_path, notice: t("support.moment.dismissed")
  end
end
