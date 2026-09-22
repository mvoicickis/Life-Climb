# frozen_string_literal: true

module MountainQuietFlash
  extend ActiveSupport::Concern

  private

  def mountain_life_journey_show_path?(path)
    path.to_s.match?(%r{/life_journeys/\d+})
  end

  def redirect_with_mountain_quiet_notice(path, notice: nil, **options)
    options[:status] ||= :see_other
    if mountain_life_journey_show_path?(path)
      redirect_to path, **options
    else
      redirect_to path, **options, notice: notice
    end
  end
end
