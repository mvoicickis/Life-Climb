require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "update how many stats to show" do
    user = users(:one)
    sign_in_as user

    patch settings_path, params: { user: { home_stat_count: 3 } }
    assert_redirected_to settings_path(highlight: "today_count")
    assert_equal 3, user.reload.home_stat_count
  end

  test "show make it yours rows" do
    user = users(:one)
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select "meta[name=app-version][content=?]", APP_VERSION
    assert_select "[data-you-page-target=version]"
    assert_select "h1", text: "You"
    assert_select "a.lp-legal-footer-links__link[href=?]", privacy_path
    assert_select "a.lp-legal-footer-links__link[href=?]", terms_path
    assert_select "a.lp-legal-footer-links__link[href=?]", delete_account_path
    assert_select "a.lp-legal-footer-links__link[href=?]", impressum_path
    assert_select ".lp-you"
    assert_select ".lp-you__profile.is-hero"
    assert_select ".lp-you__cover-img[src*='mountain_trail_day']"
    assert_select "#you-avatar.lp-you-avatar.is-lg"
    assert_select ".lp-you__avatar-initial.is-lg", text: "O"
    assert_select ".lp-you__name-text.is-hero", text: /One/
    assert_select ".lp-you__since button.lp-you__edit", text: I18n.t("settings.edit")
    assert_select ".lp-you__stats .lp-you__stat", count: 3
    assert_select ".lp-dash-nav.is-v4"
    assert_select "a.lp-dash-nav__link[href=?]", dashboard_path
    assert_select "a.lp-dash-nav__link[href=?]", life_points_path
    assert_select "a.lp-dash-nav__link[href=?]", settings_path
    assert_select ".lp-dash-nav__link.is-active", text: /You/i
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /Stats/i
    assert_select ".lp-dash-nav__fab", count: 0
    assert_select "a[href=?]", edit_today_count_settings_path, count: 0
    assert_select "a#you-row-today-count", count: 0
    assert_select "a#you-row-life-area", count: 0
    assert_select "#you-character", count: 0
    assert_select "#you-theme", count: 0
    assert_select "html[data-theme=light]"
    assert_select "#you-language", count: 0
    assert_select "#you-reminders[data-controller=?]", "push-reminders"
    assert_select "#you-reminders button[data-action=?]", "click->push-reminders#enable"
    assert_select "#you-reminders button[data-action=?]", "click->push-reminders#toggleSwitch"
    assert_select "#you-reminders button[data-action=?]", "click->push-reminders#sendTest", count: 0
    assert_select "#you-reminders [data-push-reminders-target=?]", "hint"
    assert_select "#you-reminders [data-push-reminders-target=?]", "hintText"
    assert_select "#you-reminders button[data-action=?]", "click->push-reminders#turnOn"
    assert_select "#you-reminders button[data-action=?]", "click->push-reminders#toggleDeniedHelp"
    assert_select "#you-reminders [data-push-reminders-target=?]", "openChrome"
    assert_select "#you-reminders [data-push-reminders-target=?]", "fixStepApps"
    assert_match(/data-off-phone-message="#{Regexp.escape(I18n.t('settings.reminders_off_phone'))}"/, response.body)
    assert_match(/data-blocked-phone-message="#{Regexp.escape(I18n.t('settings.reminders_blocked_phone'))}"/, response.body)
    assert_match(/data-unsupported-chrome-message="#{Regexp.escape(I18n.t('settings.reminders_unsupported_chrome'))}"/, response.body)
    assert_select "#you-climb-together"
    assert_select "#you-row-climb-together"
    assert_select ".lp-you-group__title", text: "App"
    assert_select ".lp-you-group__title", text: "Friends"
    assert_select ".lp-you-group__title", text: "Account"
    assert_select "#you-admin-group", count: 0
    assert_select "a#you-row-notifications", count: 0
    assert_select "a[href=?]", support_path, count: 0
    assert_select "a[href=?]", pricing_path
    assert_select "a#you-row-feedback[href=?]", new_feedback_path
    assert_select "a[href=?]", new_password_path
    assert_select "a[href=?]", about_path, count: 0
    assert_select "form[action=?]", session_path
    assert_select "form[action=?][data-action=?]", session_path, "submit->offline-page-cache#clearBeforeSignOut"
    assert_select ".lp-you-signout.lp-you-row--signout", text: /Sign out/i
    assert_select ".lp-you__delete-link[data-action=?]", "click->delete-account#open"
    assert_select "[data-delete-account-target=dialog]"
    assert_select ".lp-feedback-fab", count: 0
    assert_select "a[href=?]", admin_root_path, count: 0
    assert_select "form[action=?]", restart_new_player_experience_developer_tools_path, count: 0
    assert_match(/data-controller="share"/, response.body)
  end

  test "You profile shows long name under the big avatar" do
    user = users(:one)
    user.update!(name: "Mareks Voicickis Extra Long Name")
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select ".lp-you__name-text.is-hero", text: "Mareks Voicickis Extra Long Name"
    assert_select ".lp-you__avatar-initial.is-lg", text: "M"
  end

  test "You cover uses default mountain when there is no goal" do
    user = users(:one)
    user.life_journeys.destroy_all
    user.strategy_goals.destroy_all
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select ".lp-you__cover-img[src*='mountain_trail_day']"
  end

  test "You climbing since uses the user time zone month" do
    user = users(:one)
    zone = "Pacific/Kiritimati"
    user.create_notification_preference!(time_zone: zone) unless user.notification_preference
    user.notification_preference.update!(time_zone: zone)
    # 2026-06-30 14:00 UTC → 2026-07-01 on Kiritimati (UTC+14)
    user.update!(created_at: Time.utc(2026, 6, 30, 14, 0, 0))
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select ".lp-you__since", text: /Climbing since July 2026/
  end

  test "You stats match Stats battle wins and finished camps" do
    user = users(:one)
    zone = "Europe/Berlin"
    user.create_notification_preference!(time_zone: zone) unless user.notification_preference
    user.notification_preference.update!(time_zone: zone)
    sign_in_as user

    travel_to Time.find_zone!(zone).local(2026, 8, 8, 12, 0, 0) do
      user.update!(created_at: Time.find_zone!(zone).local(2026, 8, 1, 8, 0, 0))
      seed_climb!(user, today_mission: "Day one battle")
      journey = user.primary_focused_journey
      camp = user.strategy_goals.where(horizon: "project", life_journey_id: journey.id).order(:id).last
      day_one = user.strategy_goals.find_by!(horizon: "day", title: "Day one battle")
      day_one.update!(completed_at: Time.find_zone!(zone).local(2026, 8, 6, 9, 0, 0))

      day_two = add_todays_battle!(
        user: user,
        project: camp,
        journey: journey,
        title: "Day two battle"
      )
      day_two.update!(
        scheduled_on: Date.new(2026, 8, 7),
        completed_at: Time.find_zone!(zone).local(2026, 8, 7, 10, 0, 0)
      )

      camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) unless b.completed_at? }
      camp.complete!

      wins = Stats::BattleWins.call(user: user)
      camps = Stats::FinishedPathCamps.total_count(user: user)

      get settings_path
      assert_response :success
      assert_select ".lp-you__stat-number", text: wins.all_time_total.to_s
      assert_select ".lp-you__stat-number", text: camps.to_s
      assert_select ".lp-you__stat-number", text: wins.days_won_total.to_s
      assert_operator wins.days_won_total, :>=, 2
    end
  end

  test "You stats show zeros for a brand new climber" do
    user = User.create!(
      name: "Fresh",
      email_address: "fresh-you-#{SecureRandom.hex(3)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select ".lp-you__stat-number", text: "0", count: 3
  end

  test "You profile query count stays flat as wins grow" do
    user = users(:one)
    zone = "Europe/Berlin"
    user.create_notification_preference!(time_zone: zone) unless user.notification_preference
    user.notification_preference.update!(time_zone: zone)
    sign_in_as user

    travel_to Time.find_zone!(zone).local(2026, 8, 10, 12, 0, 0) do
      seed_climb!(user, today_mission: "Flat query battle")
      battle = user.strategy_goals.find_by!(horizon: "day", title: "Flat query battle")
      battle.update!(completed_at: Time.find_zone!(zone).local(2026, 8, 9, 9, 0, 0))

      get settings_path # warm climb-invite / partner lookups
      assert_response :success
      one_count = count_you_queries { get settings_path }
      assert_response :success

      journey = user.primary_focused_journey
      camp = user.strategy_goals.where(horizon: "project", life_journey_id: journey.id).order(:id).last
      5.times do |index|
        extra = add_todays_battle!(
          user: user,
          project: camp,
          journey: journey,
          title: "Extra win #{index}"
        )
        day = Date.new(2026, 8, 4) + index
        extra.update!(
          scheduled_on: day,
          completed_at: Time.find_zone!(zone).local(day.year, day.month, day.day, 11, 0, 0)
        )
      end

      many_count = count_you_queries { get settings_path }
      assert_response :success
      assert_equal one_count, many_count
    end
  end

  test "inline name edit targets stay on the You header" do
    user = users(:one)
    sign_in_as user

    get settings_path(highlight: "name")
    assert_response :success
    assert_select "[data-you-page-target=nameButton][hidden]"
    assert_select "form.lp-you__name-form.is-hero:not([hidden])"
    assert_select "[data-you-page-target=nameInput]"
  end

  test "admin sees admin row on You" do
    sign_in_as users(:admin)

    get settings_path
    assert_response :success
    assert_select "#you-admin-group .lp-you-group__title", text: "Admin"
    assert_select "a[href=?]", admin_root_path
    assert_select "#you-two-factor"
    assert_select "#you-two-factor .lp-you-row__value", text: /On|Off/
  end

  test "developer sees restart NPE on You" do
    user = users(:one)
    user.update_columns(developer: true)
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select "form[action=?]", restart_new_player_experience_developer_tools_path
    assert_match(/Restart New Player Experience/, response.body)
  end

  test "html always uses light theme" do
    user = users(:one)
    user.update!(theme: "dark")
    sign_in_as user

    get settings_path
    assert_response :success
    assert_select "html[data-theme=light]"
    assert_match(/name="theme-color" content="#f8fafc"/, response.body)
  end

  test "update character from settings" do
    user = users(:one)
    sign_in_as user
    assert_nil user.character

    patch settings_path, params: { user: { character: "fox" } }
    assert_redirected_to settings_path(highlight: "character")
    assert_equal "fox", user.reload.character
    assert_equal "characters/fox.png", user.character_image
    assert user.companion_pick_done?
    refute user.needs_companion_pick?
  end

  test "legacy character users see companion re-pick prompt until they choose" do
    user = users(:one)
    user.update_columns(
      character: "man",
      onboarding_completed_at: Time.current,
      planning_version: 2
    )
    sign_in_as user
    seed_climb!(user)

    get dashboard_path
    assert_response :success
    assert_select "#companion-pick-prompt"
    assert_select "#companion-pick-prompt .lp-companion-pick__option input[name='user[character]'][value=fox]"
    assert_select "#companion-pick-prompt .lp-companion-pick__option input[name='user[character]'][value=raven]"
    assert_select "#companion-pick-prompt .lp-ob__title", text: I18n.t("companion.prompt_title")
    assert_select "#companion-pick-prompt button[type=submit]", count: 0

    patch companion_pick_path,
          params: { user: { character: "bee" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "bee", user.reload.character
    refute user.needs_companion_pick?

    get dashboard_path
    assert_response :success
    assert_select "#companion-pick-prompt", count: 0
  end

  test "edit name page and update" do
    user = users(:one)
    sign_in_as user

    get edit_name_settings_path
    assert_response :success

    patch settings_path, params: { user: { name: "Alex" } }
    assert_redirected_to settings_path(highlight: "name")
    assert_equal "Alex", user.reload.name
  end

  test "edit today count page" do
    user = users(:one)
    sign_in_as user

    get edit_today_count_settings_path
    assert_response :success
    assert_select "[data-controller='number-stepper']"
  end

  test "reorder home habits for current user only" do
    user = users(:one)
    sign_in_as user
    a = user.habits.create!(name: "A", unit: "times", points: 5, frequency: "daily", show_on_home: true, position: 1)
    b = user.habits.create!(name: "B", unit: "times", points: 5, frequency: "daily", show_on_home: true, position: 2)

    patch reorder_settings_path, params: { habit_ids: [ b.id, a.id ] }, as: :json
    assert_response :success
    assert_equal 1, b.reload.position
    assert_equal 2, a.reload.position
  end

  test "feedback FAB gone on You and Today" do
    user = users(:one)
    sign_in_as user
    seed_climb!(user)

    get settings_path
    assert_response :success
    assert_select "a#you-row-feedback[href=?]", new_feedback_path
    assert_select ".lp-feedback-fab", count: 0

    get dashboard_path
    assert_response :success
    assert_select ".lp-feedback-fab", count: 0
  end

  private

  def count_you_queries
    queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

      queries += 1 if payload[:sql].present?
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    queries
  end
end
