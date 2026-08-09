class SettingsController < ApplicationController
  def show
    @home_habits = current_user.home_board_habits
    @all_habits = current_user.habits.active.ordered
    @commitment_journey = current_user.primary_focused_journey
  end

  def edit_name
  end

  def edit_today_count
  end

  def update
    if current_user.update(settings_params)
      current_user.mark_companion_pick_done! if updating?(:character) && current_user.character_chosen?
      redirect_to settings_path(highlight: highlight_key), notice: update_notice
    else
      render update_error_template, status: :unprocessable_entity
    end
  end

  def update_commitment
    journey = current_user.primary_focused_journey
    unless journey
      redirect_to settings_path, alert: t("settings.commitment.need_journey") and return
    end

    preset = params[:commitment_key].to_s
    begin
      if Today::Commitment::PRESETS.key?(preset)
        Today::Commitment.apply_preset!(journey, preset)
      else
        Today::Commitment.apply_custom!(
          journey,
          name: params[:commitment_name],
          habit_count: params[:commitment_habit_count],
          battle_count: params[:commitment_battle_count]
        )
      end
    rescue Today::Commitment::IneligibleError => e
      redirect_to settings_path(highlight: "commitment"),
                  alert: Today::Commitment.gap_alert(e.eligibility) and return
    end

    redirect_to commitment_redirect_path, notice: t("settings.commitment.updated")
  end

  def reorder
    ids = Array(params[:habit_ids]).map(&:to_i)
    habits = current_user.habits.where(id: ids).index_by(&:id)

    ActiveRecord::Base.transaction do
      ids.each_with_index do |id, index|
        habit = habits[id]
        next unless habit

        habit.update!(position: index + 1)
      end
    end

    head :ok
  end

  def update_habit
    habit = current_user.habits.find(params[:id])
    habit.update!(show_on_home: ActiveModel::Type::Boolean.new.cast(params[:show_on_home]))
    redirect_to settings_path, notice: "Today list updated."
  end

  private

  def settings_params
    params.require(:user).permit(:home_stat_count, :character, :name, :theme)
  end

  def update_notice
    if updating?(:name)
      t("settings.name_updated")
    elsif updating?(:character)
      t("settings.character_updated")
    elsif updating?(:theme)
      t("settings.theme_updated")
    elsif updating?(:home_stat_count)
      t("settings.today_count_updated")
    else
      "Today board updated."
    end
  end

  def highlight_key
    if updating?(:name)
      "name"
    elsif updating?(:character)
      "character"
    elsif updating?(:theme)
      "theme"
    elsif updating?(:home_stat_count)
      "today_count"
    end
  end

  def update_error_template
    if updating?(:name)
      :edit_name
    elsif updating?(:home_stat_count)
      :edit_today_count
    else
      @home_habits = current_user.home_board_habits
      @all_habits = current_user.habits.active.ordered
      :show
    end
  end

  def updating?(attribute)
    params.fetch(:user, {}).key?(attribute)
  end

  def commitment_redirect_path
    case params[:return_to].to_s
    when "today" then dashboard_path
    else settings_path(highlight: "commitment")
    end
  end
end
