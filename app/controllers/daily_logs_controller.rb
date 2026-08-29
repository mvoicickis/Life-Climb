class DailyLogsController < ApplicationController
  include MountainSheetRefresh

  before_action :set_habit
  before_action :verify_mountain_context!, if: :mountain_return?

  MODES = %w[add set undo].freeze
  UNDO_SESSION_KEY = "habit_log_undo"

  def create
    mode = params[:mode].to_s
    unless MODES.include?(mode)
      respond_log_failure!(t("habits.log_bad_mode"))
      return
    end

    case mode
    when "add" then create_add!
    when "set" then create_set!
    when "undo" then create_undo!
    end
  end

  private

  def create_add!
    delta = parse_amount(daily_log_params[:amount])
    unless delta&.positive?
      respond_log_failure!(t("habits.log_need_add"))
      return
    end

    @daily_log = current_user.daily_logs.find_or_initialize_by(habit: @habit, logged_on: Date.current)
    previous = @daily_log.persisted? ? @daily_log.amount : BigDecimal("0")
    @daily_log.amount = previous + delta
    @daily_log.goal = goal_for_log

    if @daily_log.save
      store_undo!(previous_amount: previous, delta: delta)
      award_rhythm_points_if_won!
      Today::OvershootBonus.sync!(user: current_user)
      respond_after_log!(redirect_flash_for_add(delta: delta, log: @daily_log))
    else
      respond_log_failure!(@daily_log.errors.full_messages.to_sentence, fallback_habit: true)
    end
  end

  def create_set!
    amount = parse_amount(daily_log_params[:amount])
    if amount.nil? || amount.negative?
      respond_log_failure!(t("habits.log_need_total"))
      return
    end

    @daily_log = current_user.daily_logs.find_or_initialize_by(habit: @habit, logged_on: Date.current)
    @daily_log.amount = amount
    @daily_log.goal = goal_for_log

    if @daily_log.save
      clear_undo!
      award_rhythm_points_if_won!
      Today::OvershootBonus.sync!(user: current_user)
      respond_after_log!(notice: notice_for_set(@daily_log))
    else
      respond_log_failure!(@daily_log.errors.full_messages.to_sentence, fallback_habit: true)
    end
  end

  def create_undo!
    entry = undo_entry
    unless entry
      respond_log_failure!(t("habits.log_undo_missing"))
      return
    end

    previous = parse_amount(entry["previous"])
    if previous.nil? || previous.negative?
      clear_undo!
      respond_log_failure!(t("habits.log_undo_missing"))
      return
    end

    @daily_log = current_user.daily_logs.find_or_initialize_by(habit: @habit, logged_on: Date.current)
    @daily_log.amount = previous
    @daily_log.goal = goal_for_log

    if @daily_log.save
      clear_undo!
      award_rhythm_points_if_won!
      Today::OvershootBonus.sync!(user: current_user)
      respond_after_log!(notice: notice_for_undo(@daily_log))
    else
      respond_log_failure!(@daily_log.errors.full_messages.to_sentence, fallback_habit: true)
    end
  end

  def respond_after_log!(flash_opts = {})
    respond_to do |format|
      format.turbo_stream do
        if mountain_return?
          render :create, status: :ok
        else
          redirect_to after_log_path, **flash_opts
        end
      end
      format.html { redirect_to after_log_path, **flash_opts }
    end
  end

  def respond_log_failure!(message, fallback_habit: false)
    alert = log_failure_alert(message)
    respond_to do |format|
      format.turbo_stream do
        if mountain_return?
          flash.now[:alert] = alert
          render :create, status: :unprocessable_entity
        else
          redirect_to after_log_path(fallback_habit: fallback_habit), alert: alert
        end
      end
      format.html { redirect_to after_log_path(fallback_habit: fallback_habit), alert: alert }
    end
  end

  # Optimistic +N pop may already have played client-side; failure must be unmistakable.
  def log_failure_alert(message)
    return message unless params[:return_to].to_s == "today"

    "#{t('dash.anytime.log_failed_title')} — #{message}"
  end

  def mountain_return?
    params[:return_to].to_s == "mountain"
  end

  def verify_mountain_context!
    assign_mountain_sheet_for_base_camp!
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  def after_log_path(fallback_habit: false)
    return dashboard_path if params[:return_to].to_s == "today"
    return mountain_after_log_path if mountain_return?
    return habit_path(@habit) if fallback_habit
    return habit_path(@habit) if @daily_log.blank?

    habit_path(@habit, saved: 1, won: (won? ? 1 : 0))
  end

  def mountain_after_log_path
    journey = current_user.life_journeys.find_by(id: params[:life_journey_id])
    return dashboard_path if journey.blank?

    life_journey_path(
      journey,
      goal_id: params[:goal_id].presence,
      plan_id: params[:plan_id].presence
    )
  end

  def award_rhythm_points_if_won!
    return unless won?
    already = current_user.life_point_ledgers.where(source: @habit).where("date(created_at) = ?", Date.current).exists?
    return if already

    LifePointsAward.new(current_user).for_rhythm!(@habit)
  end

  def set_habit
    @habit = current_user.habits.find(params[:habit_id])
  end

  def daily_log_params
    params.fetch(:daily_log, {}).permit(:amount, :goal)
  end

  def goal_for_log
    return @habit.goal if @habit.growth? && @habit.goal.present?
    return nil if @habit.standard?

    daily_log_params[:goal].presence || @habit.suggested_goal_for_today
  end

  def won?
    @habit.met_habit_goal? || (@daily_log.goal.present? && @daily_log.met_goal?)
  end

  def parse_amount(raw)
    return nil if raw.nil? || raw.to_s.strip.blank?

    BigDecimal(raw.to_s)
  rescue ArgumentError
    nil
  end

  def store_undo!(previous_amount:, delta:)
    bag = session[UNDO_SESSION_KEY]
    bag = {} unless bag.is_a?(Hash)
    bag = bag.stringify_keys
    bag[@habit.id.to_s] = {
      "previous" => previous_amount.to_s("F"),
      "delta" => delta.to_s("F"),
      "on" => Date.current.iso8601
    }
    session[UNDO_SESSION_KEY] = bag
  end

  def clear_undo!
    bag = session[UNDO_SESSION_KEY]
    return unless bag.is_a?(Hash)

    bag = bag.stringify_keys
    bag.delete(@habit.id.to_s)
    session[UNDO_SESSION_KEY] = bag
  end

  def undo_entry
    bag = session[UNDO_SESSION_KEY]
    return nil unless bag.is_a?(Hash)

    entry = bag.stringify_keys[@habit.id.to_s]
    return nil unless entry.is_a?(Hash)
    return nil unless entry["on"] == Date.current.iso8601

    entry
  end

  def notice_for_add(delta:, log:)
    t(
      "habits.log_added",
      delta: format_num(delta),
      total: format_num(log.amount),
      unit: log.habit.unit
    )
  end

  def redirect_flash_for_add(delta:, log:)
    if params[:return_to].to_s == "today"
      habit = log.habit
      progress = habit.goal_progress_percent
      body =
        if progress.is_a?(Numeric) && progress >= 100
          I18n.t("dash.hero.toast_hit", name: habit.name, percent: progress.to_i)
        elsif progress.is_a?(Numeric)
          I18n.t("dash.hero.toast_progress", name: habit.name, percent: progress.to_i)
        end
      {
        flash: {
          lp_toast: {
            icon: (progress.is_a?(Numeric) && progress >= 100) ? "✦" : "✓",
            title: notice_for_add(delta: delta, log: log),
            body: body,
            undo_habit_id: habit.id
          }
        }
      }
    else
      { notice: notice_for_add(delta: delta, log: log) }
    end
  end

  def notice_for_set(log)
    habit = log.habit
    parts = [ t("habits.log_set", total: format_num(log.amount), unit: habit.unit) ]
    parts << habit.status_label
    parts << t("habits.goal_hit") if habit.met_habit_goal?
    parts.join(" ")
  end

  def notice_for_undo(log)
    t("habits.log_undone", total: format_num(log.amount), unit: log.habit.unit)
  end

  def format_num(amount)
    amount = BigDecimal(amount.to_s)
    amount == amount.to_i ? amount.to_i : amount
  end
end
