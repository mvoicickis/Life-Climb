# frozen_string_literal: true

require "test_helper"

class MountainTrailTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Trail summit"
    }
    @goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @goal.id, horizon: "plan", title: "Main path"
    }
    @plan = @user.strategy_goals.for_kind("plan").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Base camp",
      color_key: "teal", trail_x: 0.48, trail_y: 0.72
    }
    @project = @user.strategy_goals.for_kind("project").last
  end

  test "mountain show renders V4 trail canvas with camps and hides holding" do
    holding_plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal,
      horizon: "plan", title: "Hold", position: 99, holding: true
    )
    holding = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: holding_plan,
      horizon: "project", title: "Secret hold", position: 0, holding: true
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#mountain-trail"
    assert_select "#trail-camps"
    assert_select "#trail-camp-#{@project.id}[aria-label=?]", "Base camp"
    assert_select "#trail-camp-#{@project.id} .lp-trail-camp__tent"
    assert_select "#trail-camp-#{@project.id} .lp-trail-camp__status"
    assert_select "#trail-spur-#{@project.id}"
    assert_select "#trail-camp-#{@project.id} .lp-trail-camp__sign", count: 0
    assert_select "#trail-camp-#{@project.id} .lp-trail-camp__post", count: 0
    assert_select "#trail-camp-#{holding.id}", count: 0
    assert_select ".lp-trail-hud"
    assert_select ".lp-trail-segments"
    assert_select ".lp-trail__stars"
    assert_select ".lp-trail__footprints"
    assert_select ".lp-trail__companion", count: 0
    assert_select ".lp-trail-camp__quick", count: 0
    assert_select ".lp-trail-camp__leader", count: 0
    assert_select "[data-action*='campPointerDown']"
    assert_select "[data-action*='surfacePointerDown']"
    assert_select "[data-relocate-hint]"
    assert_select ".lp-trail__backlight"
    assert_select ".lp-trail-coach"
    assert_select ".lp-dash-nav.is-v4 .lp-dash-nav__fab"
    assert_select ".lp-rpg-scenic", count: 0
    assert_match(/mountain_trail_default|mountain_photo/, response.body)
  end

  test "battle sheet includes daily toggle and checkbox rows" do
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Pitch the tent", scheduled_on: Date.current, position: 0
    )
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Stretch", scheduled_on: Date.current, position: 1, repeat: "daily"
    )
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__daily-switch"
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__tick"
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__kebab[data-controller='tcard-menu']"
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__dock-spacer"
    assert_select "#trail-base-sheet .lp-trail-battles__kebab[data-controller='tcard-menu']"
    assert_select "#trail-base-sheet .lp-trail-battles__dock-spacer"
    assert_select "#trail-base-sheet .lp-trail-battles__composer.is-dock"
    assert_select "#trail-battles-#{@project.id} .lp-trail-plant__wheel", count: 0
  end

  test "planting quantified range project persists quantity_kind" do
    assert_difference -> { @plan.children.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id, life_journey_id: @journey.id,
        parent_id: @plan.id, horizon: "project", title: "Sleep band",
        color_key: "blue", trail_x: 0.5, trail_y: 0.6,
        track_quantity: "1", quantity_kind: "range",
        range_min: "6", range_max: "8", unit: "hours"
      }
    end
    camp = @user.strategy_goals.for_kind("project").order(:id).last
    assert_equal "range", camp.quantity_kind
    assert_equal 6, camp.range_min.to_i
    assert_equal 8, camp.range_max.to_i
    assert camp.quantified?
  end

  test "mountain v4 phone includes cream tabs journey and today card hooks" do
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Pitch the tent", scheduled_on: Date.current,
      position: 0, repeat: "daily"
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select ".lp-dash-nav.is-v4 a[href='#{life_points_path}']"
    assert_select ".lp-dash-nav.is-v4 a[href='#{dashboard_path}']"
    assert_select ".lp-trail__peak"
    assert_select ".lp-trail__pennant"
    assert_select ".lp-trail__peak-title"
    assert_select ".lp-trail__summit-cover", count: 1
    assert_select ".lp-trail__mountain .lp-trail__dock", count: 0
    assert_select ".lp-trail__scroll > .lp-trail__dock .lp-trail-base-card"
    assert_select "#mountain-trail > .lp-trail__dock", count: 0
    assert_select ".lp-trail-base-card.is-busy"
    assert_select ".lp-trail-base-card[data-action*='openBase']"
    assert_select ".lp-trail-base-card__kicker", text: /Base camp/i
    assert_select ".lp-trail-base-card__sub", text: /Open Today/
    assert_select "#trail-sheet-camp-base"
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__kind"
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__kebab"
    assert_select ".lp-trail-camp__shadow", minimum: 1
    assert_match(/--lp-base-y:\s*0\.95/, response.body)
    assert_select ".lp-trail-sheet"
    assert_select ".lp-trail__plant-colors"
    assert_select ".lp-trail-plant__wheel", count: 0
    assert_select ".lp-trail-plant__hue-range", count: 0
    assert_select ".lp-trail-plant__metric-card.is-selected", count: 0
    assert css_select(".lp-trail-plant input[name='quantity_kind']").none? { |input| input["checked"] }
    assert_select ".lp-trail-plant__metric-follow[hidden]"
    assert_select ".lp-trail-plant__metric-fields[hidden]"
    assert_select ".lp-trail-plant__ask-btn", minimum: 2
  end

  test "planting a quantified camp without a target still tracks the number" do
    assert_difference -> { @plan.children.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id, life_journey_id: @journey.id,
        parent_id: @plan.id, horizon: "project", title: "Pages log",
        color_key: "green", trail_x: 0.5, trail_y: 0.6,
        track_quantity: "1", quantity_kind: "up", unit: "pages"
      }
    end
    camp = @user.strategy_goals.for_kind("project").find_by!(title: "Pages log")
    assert camp.quantified?
    assert_equal "up", camp.quantity_kind
    assert_equal "pages", camp.unit
    assert camp.target_amount.blank?
  end

  test "planting a project via turbo stream appends a trail camp" do
    assert_difference -> { @plan.children.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: @plan.id,
        horizon: "project",
        title: "Ridge camp",
        trail_x: 0.52,
        trail_y: 0.44,
        color_key: "amber"
      }, as: :turbo_stream
    end
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    created = @plan.children.for_kind("project").find_by!(title: "Ridge camp")
    assert_includes response.body, "trail-camps"
    assert_includes response.body, "trail-camp-#{created.id}"
    expected = MountainTrailHelper::AutoSlot.snap(0.52, 0.44)
    assert_in_delta expected[:trail_x], created.trail_x, 0.0001
    assert_in_delta expected[:trail_y], created.trail_y, 0.0001
  end

  test "camp sheet lists day battles and win forms" do
    battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Pack the tent", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-sheet-camp-#{@project.id}"
    assert_select ".lp-trail-sheet__crumb"
    assert_select ".lp-trail-sheet__close", count: 0
    assert_select "#trail-battles-#{@project.id} #trail-battle-#{battle.id}", text: /Pack the tent/
    assert_select "#trail-battles-#{@project.id} form[action*='battle_win']"
    assert_select "#trail-battles-#{@project.id} form.lp-trail-battles__camp-finish-form[action=?]",
                  strategy_goal_manual_completion_path(@project)
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__camp-finish", text: /Mark finished/
    assert_select "#trail-camp-#{@project.id}.is-current .lp-trail-camp__tent"
    assert_select "#trail-camp-#{@project.id} .lp-trail-camp__fire"
    assert_select "#trail-camp-#{@project.id} .lp-trail-camp__title", text: /Base camp/
    markup = css_select("#trail-battles-#{@project.id}").first.to_s
    assert_includes markup, "lp-trail-battles__composer is-dock"
    assert_operator markup.index("lp-trail-battles__camp-actions"), :<, markup.index("is-dock")
    assert_includes markup, "lp-trail-battles__camp-fold"
  end

  test "moving a camp patches trail coords" do
    patch strategy_goal_path(@project), params: { trail_x: 0.41, trail_y: 0.66 }
    assert_response :redirect
    @project.reload
    expected = MountainTrailHelper::AutoSlot.snap(0.41, 0.66)
    assert_in_delta expected[:trail_x], @project.trail_x, 0.0001
    assert_in_delta expected[:trail_y], @project.trail_y, 0.0001
  end

  test "show pins unplaced camps and keeps those coords after the list changes" do
    unplaced = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Drift camp", position: 2
    )
    assert_nil unplaced.trail_x
    assert_nil unplaced.trail_y

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    unplaced.reload
    assert unplaced.trail_x.present?
    assert unplaced.trail_y.present?
    pinned_x = unplaced.trail_x
    pinned_y = unplaced.trail_y

    @project.update!(completed_at: Time.current, manually_completed_at: Time.current)
    @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Later camp", position: 3
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    unplaced.reload
    assert_in_delta pinned_x, unplaced.trail_x, 0.0001
    assert_in_delta pinned_y, unplaced.trail_y, 0.0001
  end

  test "every tent has a caption under it and no side chip" do
    extra = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Ridge lookout", position: 1,
      trail_x: 0.5, trail_y: 0.55, color_key: "amber"
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-camp-#{@project.id}[aria-label=?]", "Base camp"
    assert_select "#trail-camp-#{extra.id}[aria-label=?]", "Ridge lookout"
    assert_select "#trail-camps .lp-trail-camp" do
      assert_select ".lp-trail-camp__caption .lp-trail-camp__title"
    end
    assert_select "#trail-camp-#{@project.id} .lp-trail-camp__caption", text: /Base camp/
    assert_select "#trail-camp-#{extra.id} .lp-trail-camp__caption", text: /Ridge loo/
    assert_select ".lp-trail-camp__chip", count: 0
    assert_select ".lp-trail-camp.is-chip-start", count: 0
  end

  test "planting a project without coords still gets an auto trail slot" do
    assert_difference -> { @plan.children.for_kind("project").count }, 1 do
      post strategy_goals_path, params: {
        life_area_id: @area.id,
        life_journey_id: @journey.id,
        parent_id: @plan.id,
        horizon: "project",
        title: "Strategy camp",
        color_key: "teal"
      }
    end
    created = @plan.children.for_kind("project").find_by!(title: "Strategy camp")
    expected = MountainTrailHelper::AutoSlot.call(index: 1, total: 2)
    assert_in_delta expected[:trail_x], created.trail_x, 0.0001
    assert_in_delta expected[:trail_y], created.trail_y, 0.0001
  end

  test "finished camps leave the mountain photo and sheet" do
    @project.update!(completed_at: Time.current, manually_completed_at: Time.current)
    still_open = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Ridge camp", position: 1,
      trail_x: 0.5, trail_y: 0.55, color_key: "amber"
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-camp-#{@project.id}", count: 0
    assert_select "#trail-sheet-camp-#{@project.id}", count: 0
    assert_select "#trail-camp-#{still_open.id}[aria-label=?]", "Ridge camp"
    assert_select "#trail-sheet-camp-#{still_open.id}"
    assert_select ".lp-trail-hud__stat[title=?]", I18n.t("strategy.rpg.trail.camps_done"), text: /1\s*\/\s*2/
  end

  test "upload and reset mountain photo" do
    photo = fixture_file_upload("mountain_trail_default.jpg", "image/jpeg")

    patch life_journey_path(@journey), params: {
      mountain_photo_intent: "upload",
      life_journey: { mountain_photo: photo }
    }
    assert_redirected_to life_journey_path(@journey)
    assert @journey.reload.mountain_photo.attached?

    # Sync purge in test (controller uses purge_later).
    perform_enqueued_jobs do
      patch life_journey_path(@journey), params: { mountain_photo_intent: "reset" }
    end
    assert_redirected_to life_journey_path(@journey)
    assert_not @journey.reload.mountain_photo.attached?
  end

  test "base camp add defaults to daily and can log a number" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-base-sheet input[name='repeat'][value='daily']"
    assert_select "#trail-base-sheet [data-trail-battles-target='dailyToggle'][checked]"
    assert_select "#trail-base-sheet [data-trail-battles-target='quantityToggle']"
    assert_select "#trail-base-sheet input[name='unit'][value='pages']"

    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @project.id, horizon: "day", scheduled_on: Date.current.to_s,
      title: "Read", repeat: "daily", track_quantity: "1", quantity_kind: "up", unit: "pages"
    }
    reading = @project.children.find_by!(title: "Read")
    assert reading.repeat_daily?
    assert reading.quantified?
    assert_equal "pages", reading.unit

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-base-battle-#{reading.id} [data-action*='openLog']"
    assert_select "#trail-base-battle-#{reading.id}", text: /pages/i
    assert_select "#trail-base-battle-#{reading.id}", text: /Log a number|Just a tick/i
  end

  test "developer sees basics block on base camp sheet for journey quantity habits" do
    @user.update_columns(developer: true)
    @user.habits.destroy_all
    habit = @user.habits.create!(
      name: "Pages read",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: false,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true,
      life_journey_id: @journey.id
    )
    @user.daily_logs.create!(habit: habit, logged_on: Date.current, amount: 12, goal: 25)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-base-sheet .lp-trail-battles__kind.is-basics"
    assert_select "#trail-base-habit-#{habit.id}", text: /Pages read/
    assert_select "#trail-base-habit-#{habit.id}", text: /12 pages/
  end

  test "non-developer does not see basics block on base camp sheet" do
    @user.update_columns(developer: false)
    @user.habits.destroy_all
    habit = @user.habits.create!(
      name: "Pages read",
      unit: "pages",
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      goal: 25,
      quantity_checkin: true,
      life_journey_id: @journey.id
    )
    @user.daily_logs.create!(habit: habit, logged_on: Date.current, amount: 12, goal: 25)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-base-sheet .lp-trail-battles__kind.is-basics", count: 0
    assert_select "#trail-base-habit-#{habit.id}", count: 0
  end

  test "base camp card opens sheet when daily is due from past scheduled_on" do
    battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Read daily", scheduled_on: Date.yesterday,
      position: 0, repeat: "daily"
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success
    assert_select "#trail-base-battle-#{battle.id}"
    assert_select ".lp-trail-base-card.is-win-next"
    assert_select ".lp-trail-base-card[data-action*='openBase']"
    assert_select ".lp-trail-base-card[data-action*='openComposerFromFab']", count: 0
  end
end
