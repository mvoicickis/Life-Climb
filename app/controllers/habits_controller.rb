class HabitsController < ApplicationController
  include CommitmentGapRefresh
  include MountainSheetRefresh

  before_action :set_habit, only: %i[ show edit update destroy raise_goal decline_goal_raise ]
  before_action :verify_mountain_context!, if: :mountain_create?
  before_action :load_journeys, only: %i[ new create edit update ]
  before_action :load_areas, only: %i[ index new create edit update show ]
  skip_before_action :load_journeys, :load_areas, if: -> { today_quick_add_sheet? || mountain_create? }

  def index
    @habits = current_user.habits.ordered.includes(:life_journey, :area)
    @areas = current_user.areas.ordered.includes(habits: :area)
    @unfiled_habits = @habits.select { |habit| habit.area_id.blank? }
  end

  def show
    insights = DashboardInsights.new(current_user, trackers: [ @habit ])
    @share_worthy = insights.personal_record?(@habit) || insights.big_boost?(@habit)
    @milestone_label =
      if insights.personal_record?(@habit)
        I18n.t("habits.milestone_record")
      elsif insights.big_boost?(@habit)
        I18n.t("habits.milestone_boost")
      end
    @sparkline = @habit.sparkline_amounts(days: 14)
    @improvement_projects = @habit.improvement_projects.for_kind("project").ordered.includes(:life_journey)
  end

  def new
    @habit = current_user.habits.build(
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      stat_type: "growth"
    )
  end

  def create
    @habit = current_user.habits.build(habit_params)
    @habit.show_on_home = true if @habit.show_on_home.nil?
    @habit.active = true if @habit.active.nil?
    @habit.stat_type = "growth" if @habit.stat_type.blank?
    clear_targets_unless_configured!
    apply_inferred_quantity_checkin_if_missing!
    return_to = params[:return_to].to_s

    if @habit.save
      if mountain_create?
        respond_to do |format|
          format.turbo_stream { render :create, status: :ok }
          format.html { redirect_to mountain_after_create_path, notice: t("strategy.rpg.trail.base_camp.habit_added") }
        end
      elsif params[:source].to_s == "commitment_gap"
        notice = if @habit.quantity_checkin?
          t("strategy.next_action.commitment_gap.unfiled_tracker_nudge")
        end
        refresh_commitment_gap_context!(
          open_reveal: params[:open_reveal].presence || "habit",
          gap_notice: notice
        )
        respond_to do |format|
          format.turbo_stream { render_commitment_gap_stream }
          format.html { redirect_to dashboard_path, notice: "Added. Start logging today — small steps count." }
        end
      elsif return_to == "journey"
        redirect_to life_points_path, notice: t("progress.stats.created")
      else
        redirect_to dashboard_path, notice: "Added. Start logging today — small steps count."
      end
    elsif mountain_create?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = @habit.errors.full_messages.to_sentence
          render :create, status: :unprocessable_entity
        end
        format.html { redirect_to mountain_after_create_path, alert: @habit.errors.full_messages.to_sentence, status: :see_other }
      end
    elsif return_to == "journey"
      redirect_to life_points_path, alert: @habit.errors.full_messages.to_sentence, status: :see_other
    elsif params[:source].to_s == "commitment_gap"
      refresh_commitment_gap_context!(open_reveal: "habit")
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = @habit.errors.full_messages.to_sentence
          render_commitment_gap_stream
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    sheet = today_quick_add_sheet?
    @habit.assign_attributes(habit_params)
    clear_targets_unless_configured! unless sheet
    return_to = params[:return_to].to_s

    if @habit.save
      if sheet
        respond_to do |format|
          format.turbo_stream { render :quick_add }
          format.html { redirect_to dashboard_path }
        end
      elsif return_to == "journey"
        notice =
          if @habit.saved_change_to_hidden_from_dashboard? && @habit.hidden_from_dashboard?
            t("progress.stats.hidden")
          else
            "Saved."
          end
        redirect_to life_points_path, notice: notice
      elsif return_to == "show"
        redirect_to habit_path(@habit), notice: "Saved."
      else
        redirect_to habits_path, notice: "Saved."
      end
    elsif sheet
      @habit.reload
      respond_to do |format|
        format.turbo_stream { render :quick_add, status: :unprocessable_entity }
        format.html { redirect_to dashboard_path, alert: @habit.errors.full_messages.to_sentence, status: :see_other }
      end
    elsif return_to == "journey"
      redirect_to life_points_path, alert: @habit.errors.full_messages.to_sentence, status: :see_other
    elsif return_to == "show"
      @sparkline = @habit.sparkline_amounts(days: 14)
      @improvement_projects = @habit.improvement_projects.for_kind("project").ordered.includes(:life_journey)
      render :show, status: :unprocessable_entity
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.destroy!
    flash[:turbo_clear_cache] = true
    redirect_to habits_path, notice: "Removed.", status: :see_other
  end

  def raise_goal
    if @habit.raise_goal!
      redirect_to habit_path(@habit), notice: "Goal raised. Keep going."
    else
      redirect_to habit_path(@habit), alert: "Set a goal first."
    end
  end

  def decline_goal_raise
    @habit.decline_goal_raise!
    redirect_to habit_path(@habit), notice: "Okay — keeping this goal for today."
  end

  private

  def set_habit
    @habit = current_user.habits.find(params[:id])
  end

  def today_quick_add_sheet?
    params[:return_to].to_s == "today" && params[:quick_add_sheet].present?
  end

  def mountain_create?
    action_name == "create" && params[:return_to].to_s == "mountain"
  end

  def verify_mountain_context!
    assign_mountain_sheet_for_base_camp!
    journey_id = params.dig(:habit, :life_journey_id).presence
    if journey_id.present? && journey_id.to_i != @journey.id
      raise ActiveRecord::RecordNotFound
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  def mountain_after_create_path
    life_journey_path(
      @journey,
      goal_id: @goal.id,
      plan_id: @plan.id
    )
  end

  def load_journeys
    @journeys = current_user.life_journeys.active.order(:title, :id)
  end

  def load_areas
    @areas = current_user.areas.ordered
  end

  def habit_params
    raw = params.require(:habit).permit(
      :name, :description, :points, :frequency, :active, :unit, :show_on_home, :position,
      :stat_type, :goal, :min_value, :max_value, :life_journey_id, :identity_label,
      :area_id, :state, :state_label_good, :state_label_attention, :hidden_from_dashboard,
      :quantity_checkin, :quick_add_amount
    )
    # Clamp client-supplied LP rewards — habits are not a free AP faucet.
    if raw[:points].present?
      raw[:points] = raw[:points].to_i.clamp(1, 50)
    end
    # Only normalize keys the client actually submitted — partial updates
    # (Tracker state chips) must not blank out area_id / journey / labels.
    raw[:life_journey_id] = raw[:life_journey_id].presence if raw.key?(:life_journey_id)
    raw[:identity_label] = raw[:identity_label].presence if raw.key?(:identity_label)
    raw[:area_id] = raw[:area_id].presence if raw.key?(:area_id)
    raw[:state] = raw[:state].presence if raw.key?(:state)
    raw[:state_label_good] = raw[:state_label_good].presence if raw.key?(:state_label_good)
    raw[:state_label_attention] = raw[:state_label_attention].presence if raw.key?(:state_label_attention)
    raw
  end

  # Journey / tracker create UIs may omit the checkbox — keep unit-based inference there.
  def apply_inferred_quantity_checkin_if_missing!
    return if params.fetch(:habit, {}).key?(:quantity_checkin)

    @habit.quantity_checkin = Habit.infer_quantity_checkin?(
      stat_type: @habit.stat_type,
      goal: @habit.goal,
      unit: @habit.unit
    )
  end

  # When "Enable a target" is off, the form still may post empty type fields —
  # force Better Than Yesterday with no stretch / range targets.
  def clear_targets_unless_configured!
    has_stretch = @habit.goal.present?
    has_range = @habit.min_value.present? || @habit.max_value.present?

    if @habit.standard?
      @habit.goal = nil
      return if has_range

      @habit.stat_type = "growth"
    elsif !has_stretch
      @habit.goal = nil
      @habit.min_value = nil
      @habit.max_value = nil
      @habit.stat_type = "growth"
    end
  end
end
