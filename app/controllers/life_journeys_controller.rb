# frozen_string_literal: true

class LifeJourneysController < ApplicationController
  before_action :require_planning_v2
  before_action :set_journey, only: %i[ show update ]

  def new
    @life_areas = current_user.life_areas.v2_selected
    redirect_to life_area_selections_path, alert: t("journeys.need_areas") and return if @life_areas.empty?

    @journey = current_user.life_journeys.new(life_area_id: params[:life_area_id])
  end

  def create
    area = current_user.life_areas.v2_selected.find(params.require(:life_journey)[:life_area_id])
    attrs = params.require(:life_journey).permit(
      :title, :ideal_scene, :current_reality, :next_win, :today_mission, :closer_percent
    )
    journey = Journeys::Create.call(
      user: current_user,
      life_area: area,
      title: attrs[:title].presence || attrs[:ideal_scene].to_s.truncate(80),
      ideal_scene: attrs[:ideal_scene],
      current_reality: attrs[:current_reality],
      next_win: attrs[:next_win],
      closer_percent: attrs[:closer_percent].presence || 30
    )
    Focus::SetJourneys.call(user: current_user, journey_ids: [ journey.id ])
    Missions::EnsureDaily.call(
      user: current_user,
      mission_title: attrs[:today_mission].presence
    )
    journey.bootstrap_setup_flags_from_content!(
      today_mission: journey.missions.for_day.primary.order(:id).first,
      today_todos: current_user.daily_todos.for_day.ordered
    )
    redirect_to dashboard_path, notice: t("journeys.created")
  rescue Journeys::Create::Error, Focus::SetJourneys::Error, ActiveRecord::RecordNotFound => e
    redirect_to new_life_journey_path, alert: e.message
  end

  def show
    prepare_climb!
  end

  def update
    if params[:closer_only].present?
      update_progress_only
      return
    end

    layer = params[:layer].to_s
    unless LifeJourney::CLIMB_LAYERS.include?(layer)
      climb_redirect(alert: t("journeys.climb.bad_layer")) and return
    end

    unless @journey.layer_unlocked?(layer)
      climb_redirect(alert: t("journeys.climb.locked")) and return
    end

    if params[:skip].present?
      skip_layer!(layer)
      return
    end

    save_layer!(layer)
  end

  private

  def set_journey
    @journey = current_user.life_journeys.find(params[:id])
  end

  def prepare_climb!
    @today_mission = @journey.missions.for_day(Date.current).primary.order(:id).first
    @today_todos = current_user.daily_todos.for_day(Date.current).ordered.to_a
    @journey.bootstrap_setup_flags_from_content!(
      today_mission: @today_mission,
      today_todos: @today_todos
    )
    @journey.reload
    @focus_layer = params[:edit].presence || @journey.first_open_layer
    @unlocked_layer = flash[:unlocked_layer]
  end

  # 303 so Turbo Drive follows PATCH/POST with a real HTML GET (not a stuck TURBO_STREAM paint).
  def climb_redirect(options = {})
    path = options.delete(:to) || life_journey_path(@journey)
    redirect_to path, **options, status: :see_other
  end

  def update_progress_only
    closer = params.dig(:life_journey, :closer_percent)
    if closer.present?
      @journey.update!(gap_percent: (100.0 - closer.to_f).clamp(0, 100).round(2))
    end
    climb_redirect(notice: t("journeys.climb.progress_saved"))
  end

  def skip_layer!(layer)
    unless LifeJourney::SKIPPABLE_LAYERS.include?(layer)
      climb_redirect(alert: t("journeys.climb.cannot_skip")) and return
    end

    @journey.mark_layer!(layer, "skipped")
    next_layer = next_after(layer)
    flash[:unlocked_layer] = next_layer
    climb_redirect(
      to: life_journey_path(@journey, edit: next_layer),
      notice: t("journeys.climb.skipped", layer: t("journeys.sections.#{section_key(layer)}"))
    )
  end

  def save_layer!(layer)
    if LifeJourney::LIST_LAYERS.key?(layer)
      save_list_layer!(layer)
      return
    end

    if layer == "today"
      save_today_layer!
      return
    end

    attrs = layer_params(layer)

    if layer == "goal" && attrs[:title].to_s.strip.blank?
      climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_goal")) and return
    end

    if layer == "scenes"
      if attrs[:ideal_scene].to_s.strip.blank? || attrs[:current_reality].to_s.strip.blank?
        climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_scenes")) and return
      end
    end

    if %w[purpose policy finished].include?(layer)
      field = LifeJourney::LAYER_FIELDS.fetch(layer).first
      if attrs[field].to_s.strip.blank?
        climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_layer")) and return
      end
    end

    @journey.assign_attributes(attrs)
    unless @journey.save
      prepare_climb!
      flash.now[:alert] = @journey.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity and return
    end
    @journey.mark_layer!(layer, "done")

    finish_layer!(layer)
  end

  def save_list_layer!(layer)
    attr = LifeJourney::LIST_LAYERS.fetch(layer)
    titles = Array(params.dig(:life_journey, attr)).map { |t| t.to_s.strip }.compact_blank
    if titles.empty?
      climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_one_item")) and return
    end

    @journey.replace_list!(attr, titles)
    @journey.mark_layer!(layer, "done")
    finish_layer!(layer)
  end

  def save_today_layer!
    mission_title = params.dig(:life_journey, :today_mission).to_s.strip
    titles = Array(params[:daily_todo_titles]).map { |t| t.to_s.strip }.compact_blank

    if titles.empty? && mission_title.blank?
      climb_redirect(to: life_journey_path(@journey, edit: "today"), alert: t("journeys.climb.need_today")) and return
    end

    if titles.size > GameRules::MAX_DAILY_TODOS
      climb_redirect(
        to: life_journey_path(@journey, edit: "today"),
        alert: t("dash.battle_day_full", max: GameRules::MAX_DAILY_TODOS)
      ) and return
    end

    sync_today_mission_title!(mission_title) if mission_title.present?
    replace_today_todos!(titles)
    @journey.mark_layer!("today", "done")
    finish_layer!("today")
  rescue ActiveRecord::RecordInvalid => e
    climb_redirect(to: life_journey_path(@journey, edit: "today"), alert: e.record.errors.full_messages.to_sentence)
  end

  def finish_layer!(layer)
    next_layer = next_after(layer)
    flash[:unlocked_layer] = next_layer
    climb_redirect(
      to: life_journey_path(@journey, edit: next_layer),
      notice: t("journeys.climb.layer_saved", layer: t("journeys.sections.#{section_key(layer)}"))
    )
  end

  def layer_params(layer)
    allowed = LifeJourney::LAYER_FIELDS.fetch(layer).dup
    allowed -= [ :today_mission ]
    params.fetch(:life_journey, {}).permit(*allowed)
  end

  def next_after(layer)
    idx = LifeJourney::CLIMB_LAYERS.index(layer.to_s)
    LifeJourney::CLIMB_LAYERS[idx + 1] || layer
  end

  def section_key(layer)
    {
      "goal" => "goal",
      "purpose" => "purpose",
      "policy" => "policy",
      "approach" => "approach",
      "program" => "program",
      "milestone" => "milestone",
      "scenes" => "ideal",
      "finished" => "finished",
      "today" => "today"
    }.fetch(layer.to_s)
  end

  def sync_today_mission_title!(title)
    title = title.to_s.strip
    return if title.blank?

    mission = @journey.missions.for_day(Date.current).primary.order(:id).first
    if mission && !mission.completed?
      mission.update!(title: title)
    elsif mission.nil?
      Missions::EnsureDaily.call(user: current_user, mission_title: title)
    end
  end

  def replace_today_todos!(titles)
    day = Date.current
    aspect = battle_aspect_key
    existing = current_user.daily_todos.for_day(day).ordered.to_a

    ActiveRecord::Base.transaction do
      titles.each_with_index do |title, index|
        if (todo = existing[index])
          todo.update!(title: title, position: index, aspect_key: aspect)
        else
          current_user.daily_todos.create!(
            title: title,
            aspect_key: aspect,
            scheduled_on: day,
            position: index,
            lp_reward: GameRules::BATTLE_TODO_LP
          )
        end
      end

      existing.drop(titles.size).each(&:destroy!)
    end
  end

  def battle_aspect_key
    key = @journey.life_area.key.to_s
    return key if LifeArea::HOME_ASPECT_KEYS.include?(key)

    "career"
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path, alert: t("journeys.need_v2")
  end
end
