# frozen_string_literal: true

require "test_helper"

class FinishMapReslotStreamTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      today_mission: "Map reslot stream",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    attach_custom_mountain_photo!
    @goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: @journey.id)
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Main path", position: 0
    )
    @camps = 4.times.map do |i|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Camp #{i + 1}",
        color_key: "teal", trail_x: 0.48, trail_y: 0.72, position: i, stage: i
      )
    end
    @camp1, @camp2, @camp3, @camp4 = @camps
    win_all_battles!(@camp1)
  end

  def attach_custom_mountain_photo!
    @journey.mountain_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/mountain_trail_default.jpg")),
      filename: "mountain_trail_default.jpg",
      content_type: "image/jpeg"
    )
  end

  def win_all_battles!(project)
    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Win", scheduled_on: Date.current, position: 0
    ).update!(completed_at: Time.current)
  end

  def camp_trail_y_from_html(html, camp_id)
    fragment = Nokogiri::HTML.fragment(html)
    camp = fragment.at_css("#trail-camp-#{camp_id}")
    return nil unless camp

    style = camp["style"].to_s
    match = style.match(/--lp-trail-y:\s*([^;]+)/)
    match ? match[1].strip.to_f : nil
  end

  test "custom photo finish stream map coordinates match fresh get" do
    post strategy_goal_manual_completion_path(@camp1), as: :turbo_stream
    assert_response :success

    stream_map_html = response.body[/turbo-stream[^>]*target="trail-map-camps"[^>]*>.*<template>(.*)<\/template>/m, 1]
    assert stream_map_html.present?, "expected trail-map-camps turbo template in response"

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-trail.is-custom-mountain-photo"

    [ @camp2, @camp3, @camp4 ].each do |camp|
      stream_y = camp_trail_y_from_html(stream_map_html, camp.id)
      get_y = camp_trail_y_from_html(response.body, camp.id)
      assert stream_y, "stream missing camp #{camp.id} y"
      assert get_y, "GET missing camp #{camp.id} y"
      assert_in_delta get_y, stream_y, 0.0001,
                      "camp #{camp.id} y mismatch stream=#{stream_y} get=#{get_y}"
    end

    refute_match(/id="trail-camp-#{@camp1.id}"/, stream_map_html)
    assert_select "#trail-map-camps", count: 1
  end
end
