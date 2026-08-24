# frozen_string_literal: true

require "test_helper"

class LifeJourneyMountainPhotoTest < ActiveSupport::TestCase
  test "journey can attach a mountain photo" do
    user = users(:one)
    area = user.life_areas.first || user.life_areas.create!(key: "career", number: 9)
    journey = user.life_journeys.create!(
      life_area: area,
      title: "Summit",
      ideal_scene: "Done",
      current_reality: "Building"
    )
    journey.mountain_photo.attach(
      io: File.open(Rails.root.join("app/assets/images/mountain_trail_default.jpg")),
      filename: "mountain_trail_default.jpg",
      content_type: "image/jpeg"
    )
    assert journey.mountain_photo.attached?
  end
end
