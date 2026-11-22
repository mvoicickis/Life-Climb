# frozen_string_literal: true

require "test_helper"

class TodayOtherMountainsTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper
  include TodayV2TestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    @focused = seed_climb!(@user, area_key: "career", title: "Focused peak", today_mission: "Focused fight")
    dismiss_onboarding_missions!(@user)
  end

  test "planet button shows badge total and lists other open mountains" do
    alpha = seed_second_journey!(title: "Alpha peak", area_key: "self", battle_title: "Alpha 1")
    alpha_camp = @user.strategy_goals.find_by!(horizon: "project", title: "Camp Alpha peak", life_journey_id: alpha.id)
    alpha_camp.children.create!(
      user: @user, life_area: alpha.life_area, life_journey: alpha,
      horizon: "day", title: "Alpha 2", scheduled_on: Date.current, position: 1
    )
    bravo = seed_second_journey!(title: "Bravo peak", area_key: "purpose", battle_title: "Bravo 1")

    get dashboard_path
    assert_response :success

    assert_select "#today-top-bar[data-controller~='dropdown']", count: 1
    assert_select "#today-top-bar .lp-other-mountains-button[aria-label=?]", I18n.t("dash.battlefield.other_mountains.open")
    assert_select "#today-top-bar .lp-other-mountains-button__face", count: 1
    assert_select "#today-top-bar .lp-other-mountains-button__face .lp-planet-icon", count: 1
    assert_select "#today-top-bar .lp-other-mountains-button__badge", text: "3"
    assert_select "#today-top-bar .lp-other-mountains-dropdown[hidden][role=?]", "menu"
    assert_select "#today-battlefield-header .lp-other-mountains-button", count: 0
    assert_select ".lp-other-mountains-dropdown__title", text: I18n.t("dash.battlefield.other_mountains.title")
    assert_select ".lp-other-mountains-row", count: 2
    assert_select ".lp-other-mountains-row__name", text: "Alpha peak"
    assert_select ".lp-other-mountains-row__name", text: "Bravo peak"
    assert_select ".lp-other-mountains-row__name", text: "Focused peak", count: 0
    names = css_select(".lp-other-mountains-row__name").map { |n| n.text.strip }
    assert_equal [ "Alpha peak", "Bravo peak" ], names
    assert_select ".lp-other-mountains-row__count", text: I18n.t("dash.battlefield.other_mountains.battles", count: 2)
    assert_select ".lp-other-mountains-row__count", text: I18n.t("dash.battlefield.other_mountains.battles", count: 1)
    assert_select ".lp-other-mountains-row__chevron.lp-chevron", count: 2
    assert_select "form.lp-other-mountains-row-form[action=?]", today_focus_path(journey_id: alpha.id)
    assert_select "form.lp-other-mountains-row-form[action=?]", today_focus_path(journey_id: bravo.id)

    css = Rails.root.join("app/assets/stylesheets/today_v2.css").read
    dropdown = css[/\.lp-dash\.is-today-v2\.is-today-photo \.lp-other-mountains-dropdown\s*\{[^}]+\}/m]
    assert dropdown.present?
    assert_match(/background:\s*var\(--lp-surface\)/, dropdown)
    refute_match(/color-mix\(in srgb, var\(--lp-surface\) 94%/, dropdown)

    top = css[/\.lp-dash\.is-today-v2\.is-today-photo \.lp-other-mountains-dropdown--top\s*\{[^}]+\}/m]
    assert top.present?
    assert_match(/left:\s*0/, top)
    assert_match(/right:\s*0/, top)
    refute_match(/left:\s*auto/, top)
  end

  test "planet button is hidden when other mountains have zero open battles" do
    other = seed_second_journey!(title: "Quiet peak", area_key: "self", battle_title: "Done fight")
    battle = @user.strategy_goals.find_by!(horizon: "day", title: "Done fight", life_journey_id: other.id)
    battle.update!(completed_at: Time.current)

    get dashboard_path
    assert_response :success

    assert_select ".lp-other-mountains-button", count: 0
    assert_select ".lp-other-mountains-dropdown", count: 0
  end

  test "custom photo thumb vs default mountain icon" do
    photo_journey = seed_second_journey!(title: "Photo peak", area_key: "self", battle_title: "Photo fight")
    photo_journey.mountain_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/mountain_trail_default.jpg")),
      filename: "custom.jpg",
      content_type: "image/jpeg"
    )
    seed_second_journey!(title: "Icon peak", area_key: "purpose", battle_title: "Icon fight")

    get dashboard_path
    assert_response :success

    assert_select ".lp-other-mountains-row__thumb img", count: 1
    assert_select ".lp-other-mountains-row__icon", count: 1
  end

  test "switch focus changes Today battles and Mountain follows" do
    second = seed_second_journey!(title: "Second peak", area_key: "self", battle_title: "Second fight")
    Strategy::CascadeToDaily.call(
      user: @user,
      life_area: second.life_area,
      from: Date.current,
      to: Date.current
    )

    get dashboard_path
    assert_response :success
    assert_select "#today-battlefield-rows", text: /Focused fight/
    assert_select "#today-battlefield-rows", text: /Second fight/, count: 0

    assert_no_difference -> { @user.missions.count } do
      patch today_focus_path, params: { journey_id: second.id }
    end
    assert_redirected_to dashboard_path
    assert_nil flash[:notice]
    follow_redirect!
    assert_response :success

    assert_equal 1, second.reload.focus_position
    assert_nil @focused.reload.focus_position
    assert_select "#today-battlefield-rows", text: /Second fight/
    assert_select "#today-battlefield-rows", text: /Focused fight/, count: 0
    assert_equal 1, css_select("#today-battlefield-rows .lp-today-v2-row").size,
                 "only the real battle shows — no daily mission row"
    assert_select "form[action*='/missions/']", count: 0
    assert_select ".lp-today-v2-header__name", text: /Second peak/

    get life_journey_path(second)
    assert_response :success
    assert_select ".lp-trail__my-world-corner .lp-planet-icon", count: 1
  end

  test "focus picker switches mountains without adding a daily mission" do
    second = seed_second_journey!(title: "Picker peak", area_key: "self", battle_title: "Picker fight")

    assert_no_difference -> { @user.missions.count } do
      patch focus_path, params: { journey_ids: [ second.id ] }
    end
    assert_redirected_to dashboard_path
    assert_equal 1, second.reload.focus_position
  end

  test "cannot switch to another users journey" do
    seed_second_journey!(title: "Mine", area_key: "self", battle_title: "My fight")
    other = users(:two)
    allow_extra_climbs!(other)
    foreign = seed_climb!(other, area_key: "career", title: "Theirs", today_mission: "Foreign fight")

    patch today_focus_path, params: { journey_id: foreign.id }
    assert_response :not_found
    assert_equal 1, @focused.reload.focus_position
  end

  test "Mountain My world pill renders the shared planet icon" do
    get life_journey_path(@focused)
    assert_response :success
    assert_select "a.lp-trail__my-world-corner[href=?]", world_path
    assert_select ".lp-trail__my-world-corner__face .lp-planet-icon", count: 1
    assert_select ".lp-trail__my-world-corner__face .planet-globe", count: 1
  end

  test "Today other-mountains query count stays flat for one vs eight other journeys" do
    seed_second_journey!(title: "Climb 1", area_key: "self", battle_title: "Battle 1")
    warm_today_lookups!

    one_queries = count_other_mountains_queries { load_other_mountains_for_today! }
    assert_operator one_queries, :<=, 4

    %w[purpose money learning relationships family home community].each_with_index do |area_key, i|
      seed_second_journey!(title: "Climb #{i + 2}", area_key: area_key, battle_title: "Battle #{i + 2}")
    end
    warm_today_lookups!

    eight_queries = count_other_mountains_queries { load_other_mountains_for_today! }
    assert_equal one_queries, eight_queries,
                 "expected flat Today queries (1-other=#{one_queries}, 8-other=#{eight_queries})"

    get dashboard_path
    assert_response :success
    assert_select ".lp-other-mountains-button__badge", text: "8"
  end

  private

  def seed_second_journey!(title:, area_key:, battle_title:)
    LifeAreas::Select.call(user: @user, keys: [ area_key ])
    area = @user.life_areas.v2_selected.find_by!(key: area_key)
    journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: title,
      ideal_scene: "Ideal #{title}",
      current_reality: "Present #{title}",
      next_win: "Next #{title}",
      closer_percent: 20
    )
    goal = @user.strategy_goals.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "goal",
      title: title,
      position: 0
    )
    plan = goal.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Plan #{title}", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Camp #{title}", position: 0
    )
    project.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "day", title: battle_title, scheduled_on: Date.current, position: 0
    )
    journey
  end

  def warm_today_lookups!
    Battles::WinsOnLocalDate.time_zone_for(@user)
    Battles::WinsOnLocalDate.local_today_for(@user)
    load_other_mountains_for_today!
  end

  # Same reads Dashboard::TodaySurface#assign_other_mountains! uses (date + focus preloaded).
  def load_other_mountains_for_today!
    focused = @user.primary_focused_journey
    date = Battles::WinsOnLocalDate.local_today_for(@user)
    result = Today::OtherMountainsOpenCounts.call(
      user: @user,
      focused_journey: focused,
      date: date
    )
    photo_ids = result.journeys.select(&:custom_photo?).map(&:journey_id)
    if photo_ids.any?
      @user.life_journeys.where(id: photo_ids).with_attached_mountain_photo.index_by(&:id)
    end
    result
  end

  def count_other_mountains_queries
    queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:cached]
      next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"
      next if payload[:sql].blank?

      queries += 1
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    queries
  end
end
