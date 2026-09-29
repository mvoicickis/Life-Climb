# frozen_string_literal: true

require "test_helper"

class TodayBasicsTickTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    enable_habits!

    @user.habits.destroy_all
    @binary = @user.habits.create!(
      name: "Meditate daily for clarity and calm",
      unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @pages = @user.habits.create!(
      name: "Pages read", unit: "pages", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth", goal: 10
    )
  end

  test "binary basic uses battle tick not I did it pill" do
    get dashboard_path
    assert_response :success

    row = "##{dom_id(@binary, :today)}"
    assert_select "#{row}.is-binary-tick .lp-today-v2-row__check", count: 1
    assert_select "#{row} .lp-dash-habit__qb.is-big", count: 0
    assert_select "#{row} form[data-juicy-feedback-win-not-saved-value=?]",
                  I18n.t("dash.battlefield.win_not_saved")
    assert_select "#{row} .lp-dash-habit__sig--trail", count: 1

    assert_select "##{dom_id(@pages, :today)} .lp-dash-habit__qb.is-big", count: 1
    assert_select "##{dom_id(@pages, :today)} .lp-dash-habit__dots", count: 1
  end

  test "binary basic meta omits percent chip" do
    post completions_path(habit_id: @binary.id)
    assert_redirected_to dashboard_path

    get dashboard_path
    assert_response :success
    assert_select "##{dom_id(@binary, :today_meta)} .lp-dash-habit__pct", count: 0
  end

  test "binary completion undo refreshes anytime host via turbo stream" do
    post completions_path(habit_id: @binary.id)
    completion = @binary.completions.find_by!(completed_on: Date.current)

    delete completion_path(completion), as: :turbo_stream
    assert_response :success
    assert_match(/turbo-stream[^>]*action="replace"[^>]*target="today-anytime-host"/, response.body)
    refute @binary.reload.completed_today?
  end

  test "binary turbo create save failure returns 422" do
    invalid = Completion.new
    invalid.errors.add(:base, "stub save failure")

    with_completion_save_stub(->(*) { raise ActiveRecord::RecordInvalid.new(invalid) }) do
      post completions_path(habit_id: @binary.id), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    refute @binary.reload.completed_today?
  end

  private

  def with_completion_save_stub(impl)
    original = Completion.instance_method(:save)
    Completion.define_method(:save) do |*args, **kwargs, &block|
      impl.call(self, *args, **kwargs, &block)
    end
    yield
  ensure
    Completion.define_method(:save, original)
  end
end
