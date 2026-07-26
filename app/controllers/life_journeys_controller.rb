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
      today_mission: journey.missions.for_day.primary.order(:id).first
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
    @journey.bootstrap_setup_flags_from_content!(today_mission: @today_mission)
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
    attrs = layer_params(layer)
    today_title = attrs.delete(:today_mission)

    if layer == "goal" && attrs[:title].to_s.strip.blank?
      climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_goal")) and return
    end

    if layer == "scenes"
      if attrs[:ideal_scene].to_s.strip.blank? || attrs[:current_reality].to_s.strip.blank?
        climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_scenes")) and return
      end
    end

    if %w[purpose policy approach program milestone finished].include?(layer)
      field = LifeJourney::LAYER_FIELDS.fetch(layer).first
      if attrs[field].to_s.strip.blank?
        climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_layer")) and return
      end
    end

    if layer == "today"
      if today_title.to_s.strip.blank?
        climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_today")) and return
      end
      sync_today_mission_title!(today_title)
      @journey.mark_layer!(layer, "done")
    else
      @journey.assign_attributes(attrs)
      unless @journey.save
        prepare_climb!
        flash.now[:alert] = @journey.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity and return
      end
      @journey.mark_layer!(layer, "done")
    end

    next_layer = next_after(layer)
    flash[:unlocked_layer] = next_layer
    climb_redirect(
      to: life_journey_path(@journey, edit: next_layer),
      notice: t("journeys.climb.layer_saved", layer: t("journeys.sections.#{section_key(layer)}"))
    )
  end

  def layer_params(layer)
    allowed = LifeJourney::LAYER_FIELDS.fetch(layer).dup
    allowed -= [ :today_mission ] if layer != "today"
    if layer == "today"
      { today_mission: params.dig(:life_journey, :today_mission) }
    else
      params.fetch(:life_journey, {}).permit(*allowed)
    end
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

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path, alert: t("journeys.need_v2")
  end
end
