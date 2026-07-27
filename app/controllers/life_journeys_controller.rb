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
    prepare_strategy!
  end

  def update
    if params[:strategy_brief].present?
      @journey.update_strategy_brief!(params.require(:strategy_brief).permit(*LifeJourney::STRATEGY_BRIEF_KEYS))
      redirect_to life_journey_path(@journey, horizon: params[:horizon].presence || "brief"),
                  notice: t("strategy.brief_saved"), status: :see_other
      return
    end

    if params[:sync_today].present?
      created = Strategy::CascadeToDaily.call(user: current_user, life_area: @journey.life_area)
      notice =
        if created.positive?
          t("strategy.synced", count: created)
        else
          t("strategy.battle_ready")
        end
      redirect_to dashboard_path, notice: notice, status: :see_other
      return
    end

    # Legacy climb updates still accepted for API compatibility, but Journey UI no longer exposes them.
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
    @journey = current_user.life_journeys.find_by(id: params[:id])
    return if @journey

    fallback = current_user.primary_focused_journey || current_user.life_journeys.active.order(:id).first
    if fallback
      redirect_to life_journey_path(fallback), alert: t("journeys.missing_redirect"), status: :see_other
    else
      redirect_to new_life_journey_path, alert: t("journeys.missing_redirect"), status: :see_other
    end
  end

  def prepare_strategy!
    area = @journey.life_area
    if area.blank?
      redirect_to new_life_journey_path, alert: t("journeys.missing_redirect"), status: :see_other
      return
    end

    @goals = current_user.strategy_goals.for_area(area.id).ordered.includes(:children, :parent)
    @goal = @goals.for_kind("goal").roots.first
    @year_due = Strategy::YearCycle.target_dec29

    @focus =
      if params[:focus_id].present?
        @goals.find { |g| g.id == params[:focus_id].to_i }
      else
        @goal
      end

    # Legacy month/week focus redirects up to the nearest active parent.
    if @focus&.month? || @focus&.week?
      @focus = @focus.ancestor_chain.reverse.find { |n| n.project? || n.plan? || n.goal? } || @goal
    end

    @focus ||= @goal
    @level = strategy_level_for(@focus)
    @children = @focus ? @focus.children.ordered.to_a : []
    @siblings = strategy_siblings(@focus)
    @today_battles = today_battles_for(@focus || @goal)
    @today_battle = @today_battles.find { |b| b.completed_at.blank? } || @today_battles.first
    @crumbs = strategy_crumbs(@focus)
    @guided_step = guided_step
    @path_stages = strategy_path_stages
    @mountain = Strategy::Mountain.for(goal: @goal)
    Climb::Streak.reconcile!(user: current_user)
    @climb_streak = Climb::Streak.status(user: current_user)
    @mountain_ready = strategy_mountain_ready?
    @next_up = strategy_next_up
    @branch_plan, @branch_project = strategy_branch_for(@focus, @today_battle)
    @sheet_node =
      if params[:node_id].present?
        @goals.find { |g| g.id == params[:node_id].to_i } || @focus
      else
        @focus
      end
    @open_sheet = params[:sheet].present?
    @open_peek = !@open_sheet && (params[:peek].present? || params[:node_id].present?)
    @force_notebook = params[:notebook].present?
    @upcoming_battle = Strategy::UpcomingBattle.for(user: current_user, journey: @journey)
    @first_climb_needed = @goal.present? && @goal.children.for_kind("plan").none?
    @notebook_guide =
      if @first_climb_needed
        nil
      elsif @goal.blank?
        nil
      elsif !@mountain_ready
        :keep_building
      elsif @upcoming_battle.present?
        :tomorrow
      else
        :fight_today
      end
  end

  def strategy_branch_for(focus, today_battle)
    plan =
      if focus&.plan?
        focus
      elsif focus&.project?
        focus.parent
      elsif focus&.day?
        focus.parent&.parent
      end
    project =
      if focus&.project?
        focus
      elsif focus&.day?
        focus.parent
      end

    # Keep Goal summit map clean: don't auto-place a Project tent from today's battle.
    # Plan can still light from today's climb so the trail reads "where am I".
    if plan.nil? && today_battle&.parent
      plan ||= today_battle.parent&.parent if focus.blank? || focus.goal?
    end

    [ plan, project ]
  end

  def strategy_mountain_ready?
    Strategy::HierarchyReady.call(user: current_user, goal: @goal)
  end

  def strategy_path_stages
    keys = %w[goal plans projects battle]
    current =
      case @guided_step
      when 1 then "goal"
      when 2 then "plans"
      when 3 then "projects"
      else "battle"
      end

    keys.map do |key|
      {
        key: key,
        label: I18n.t("strategy.path.#{key}"),
        state: path_stage_state(key, current, keys)
      }
    end
  end

  def path_stage_state(key, current, keys)
    ci = keys.index(current)
    ki = keys.index(key)
    return :current if key == current
    return :done if ki < ci

    :upcoming
  end

  def strategy_next_up
    if @goal.nil?
      return {
        key: :create_goal,
        title: I18n.t("strategy.questions.goal"),
        hint: I18n.t("strategy.next_up.create_goal_hint"),
        cta: I18n.t("strategy.next_up.create_goal_cta"),
        placeholder: I18n.t("strategy.goal_placeholder"),
        examples: [ I18n.t("strategy.next_up.example_goal") ],
        form: { horizon: "goal", parent_id: nil }
      }
    end

    # Inside a project: always plan battles here first. Handoff only after this project has at least one.
    if @focus&.project?
      battles = @children.select(&:day?)
      if battles.empty?
        return {
          key: :add_battle,
          title: I18n.t("strategy.questions.battle"),
          hint: I18n.t("strategy.next_up.add_battle_hint"),
          cta: I18n.t("strategy.next_up.add_battle_cta"),
          placeholder: I18n.t("strategy.battle_placeholder"),
          examples: [ I18n.t("strategy.next_up.example_battle") ],
          form: { horizon: "day", parent_id: @focus.id, scheduled_on: Date.current }
        }
      end

      return mountain_ready_next_up if @mountain_ready

      return {
        key: :add_battle,
        title: I18n.t("strategy.questions.battle"),
        hint: I18n.t("strategy.next_up.add_another_battle_hint"),
        cta: I18n.t("strategy.next_up.add_another_battle_cta"),
        placeholder: I18n.t("strategy.battle_placeholder"),
        examples: [ I18n.t("strategy.next_up.example_battle") ],
        form: { horizon: "day", parent_id: @focus.id, scheduled_on: Date.current }
      }
    end

    if @mountain_ready && (@today_battles.any? || @level == "plans")
      return mountain_ready_next_up
    end

    if @level == "plans"
      plans = @children.select(&:plan?)
      if plans.empty?
        return {
          key: :add_plan,
          title: I18n.t("strategy.questions.plan"),
          hint: I18n.t("strategy.next_up.add_plan_hint"),
          cta: I18n.t("strategy.next_up.add_plan_cta"),
          placeholder: I18n.t("strategy.plan_placeholder"),
          examples: [ I18n.t("strategy.next_up.example_plan") ],
          form: { horizon: "plan", parent_id: @goal.id }
        }
      end

      target = plans.min_by { |p| p.progress_percent }
      return {
        key: :open_child,
        title: I18n.t("strategy.next_up.open_plan_title", title: target.title),
        hint: I18n.t("strategy.next_up.open_plan_hint"),
        cta: I18n.t("strategy.next_up.enter_plan_cta"),
        href: life_journey_path(@journey, focus_id: target.id),
        zoom: true
      }
    end

    if @level == "projects" && @focus&.plan?
      projects = @children.select(&:project?)
      if projects.empty?
        return {
          key: :add_project,
          title: I18n.t("strategy.questions.project"),
          hint: I18n.t("strategy.next_up.add_project_hint"),
          cta: I18n.t("strategy.next_up.add_project_cta"),
          placeholder: I18n.t("strategy.project_placeholder"),
          examples: [ I18n.t("strategy.next_up.example_project") ],
          form: { horizon: "project", parent_id: @focus.id }
        }
      end

      target = projects.min_by { |p| p.progress_percent }
      return {
        key: :open_child,
        title: I18n.t("strategy.next_up.open_child_title", title: target.title),
        hint: I18n.t("strategy.next_up.open_child_hint"),
        cta: I18n.t("strategy.next_up.open_project_cta"),
        href: life_journey_path(@journey, focus_id: target.id),
        zoom: true
      }
    end

    if @today_battles.any?
      mountain_ready_next_up
    else
      {
        key: :keep_building,
        title: I18n.t("strategy.next_up.keep_building_title"),
        hint: I18n.t("strategy.next_up.keep_building_hint"),
        cta: I18n.t("strategy.next_up.keep_building_cta"),
        anchor: "strategy-quests"
      }
    end
  end

  def mountain_ready_next_up
    {
      key: :go_today,
      title: I18n.t("strategy.next_up.mountain_ready_title"),
      hint: I18n.t("strategy.next_up.mountain_ready_hint"),
      cta: I18n.t("strategy.next_up.fight_today_cta"),
      sync_today: true
    }
  end

  def strategy_level_for(node)
    return "goal" if node.blank?

    case node.kind
    when "goal" then "plans"
    when "plan" then "projects"
    when "project" then "battles"
    else "battles"
    end
  end

  def guided_step
    return 1 if @goal.blank?
    return 2 if @goal.children.for_kind("plan").none?

    plan_ids = @goal.children.for_kind("plan").select(:id)
    return 3 if StrategyGoal.where(parent_id: plan_ids).for_kind("project").none?
    return 4 if Strategy::Progress.battles_under(@goal).none?

    5
  end

  def today_battles_for(node)
    return [] if node.blank?

    root = node.goal? ? node : node.root_goal
    return [] if root.blank?

    Strategy::Progress.battles_under(root).select { |b| b.scheduled_on == Date.current }
  end

  def strategy_crumbs(node)
    return [] if node.blank?

    ([ node ] + node.ancestor_chain.reverse).reverse.map do |n|
      { id: n.id, title: n.title, kind: n.kind }
    end
  end

  # Peer plans under the same goal, or peer projects under the same plan.
  def strategy_siblings(focus)
    return [] unless focus&.plan? || focus&.project?
    return [] if focus.parent_id.blank?

    @goals.select { |g| g.parent_id == focus.parent_id && g.kind == focus.kind }
  end

  def prepare_climb!
    @today_mission = @journey.missions.for_day(Date.current).primary.order(:id).first
    @today_todos = current_user.daily_todos.for_day(Date.current).ordered.to_a
    @targets = @journey.journey_targets.ordered.to_a
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
    raw = params.dig(:life_journey, attr)
    entries =
      if raw.is_a?(Array) && raw.first.is_a?(ActionController::Parameters)
        raw
      elsif raw.is_a?(Array)
        # Parallel title + tags arrays from climb list UI
        titles = Array(params.dig(:life_journey, attr))
        tags = Array(params.dig(:life_journey, :"#{attr}_tags"))
        titles.each_with_index.map { |title, i| { title: title, tags: tags[i] } }
      else
        Array(raw)
      end

    items = entries
    if items.empty? || items.all? { |e| e.is_a?(String) ? e.blank? : e[:title].to_s.strip.blank? && e["title"].to_s.strip.blank? }
      # try structured
    end

    cleaned_preview = items.filter_map do |e|
      if e.is_a?(String)
        e.to_s.strip.presence
      else
        h = e.respond_to?(:to_unsafe_h) ? e.to_unsafe_h : e
        (h["title"] || h[:title]).to_s.strip.presence
      end
    end
    if cleaned_preview.empty?
      climb_redirect(to: life_journey_path(@journey, edit: layer), alert: t("journeys.climb.need_one_item")) and return
    end

    @journey.replace_list!(attr, items)
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
    tags = Array(params[:daily_todo_tags])
    existing = current_user.daily_todos.for_day(day).ordered.to_a

    ActiveRecord::Base.transaction do
      titles.each_with_index do |title, index|
        tag = tags[index].to_s.split(/[,\s]+/).map { |t| t.strip.downcase }.compact_blank.first
        if (todo = existing[index])
          todo.update!(title: title, position: index, aspect_key: aspect, tag: tag)
        else
          current_user.daily_todos.create!(
            title: title,
            aspect_key: aspect,
            scheduled_on: day,
            position: index,
            lp_reward: GameRules::BATTLE_TODO_LP,
            tag: tag
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
