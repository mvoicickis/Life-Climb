# frozen_string_literal: true

# Idempotent Money-focused Mountain demo for demo@lifepoints.test.
# Safe to re-run: find-or-create by title + parent; complete! only when open.
#
# Quest Space counts PracticeTask rows on one host day
# (Strategy::EnsureFolderQuest::HOST_TITLE), not sibling day StrategyGoals.

demo_user = User.find_by!(email_address: "demo@lifepoints.test")

JOURNEY_TITLE = "Reach $10k/month with LifePoints"
PLAN_TITLE = "Main path"
STEPS_TITLE = "Steps"
HOST_TITLE = Strategy::EnsureFolderQuest::HOST_TITLE

CHECKPOINT_TITLES = [
  "Nail the MVP experience",
  "Launch to first 100 users",
  "Build a referral loop",
  "Launch a paid tier",
  "Scale to 1,000 subscribers"
].freeze

OBJECTIVES = [
  { title: "Fix onboarding drop-off", complete: true },
  { title: "Add a referral share button", complete: true },
  { title: "Post in 3 founder communities", complete: false },
  { title: "Set up basic analytics", complete: false }
].freeze

LifeAreas::Select.call(user: demo_user, keys: [ "money" ])
area = demo_user.life_areas.find_by!(key: "money")

journey = demo_user.life_journeys.find_by(life_area_id: area.id, title: JOURNEY_TITLE)
if journey.nil?
  journey = Journeys::Create.call(
    user: demo_user,
    life_area: area,
    title: JOURNEY_TITLE,
    ideal_scene: "LifePoints earns $10k/month from paying subscribers who climb every day.",
    current_reality: "Product works for me; few people pay yet.",
    next_win: "Launch to first 100 users",
    closer_percent: 15
  )
else
  journey.update!(gap_percent: 85, status: "active") if journey.gap_percent.to_f != 85.0
end

Focus::SetJourneys.call(user: demo_user, journey_ids: [ journey.id ])

ensure_child = lambda do |parent:, horizon:, title:, position:, scheduled_on: nil|
  scope = demo_user.strategy_goals.where(
    life_area_id: area.id,
    parent_id: parent&.id,
    horizon: horizon,
    title: title
  )
  goal = scope.first
  if goal
    attrs = {}
    attrs[:position] = position if goal.position != position
    attrs[:life_journey] = journey if goal.life_journey_id != journey.id
    attrs[:scheduled_on] = scheduled_on if scheduled_on && goal.scheduled_on != scheduled_on
    goal.update!(attrs) if attrs.any?
    goal
  else
    demo_user.strategy_goals.create!(
      life_area: area,
      life_journey: journey,
      parent: parent,
      horizon: horizon,
      title: title,
      position: position,
      scheduled_on: scheduled_on
    )
  end
end

goal = ensure_child.call(parent: nil, horizon: "goal", title: JOURNEY_TITLE, position: 0)
plan = ensure_child.call(parent: goal, horizon: "plan", title: PLAN_TITLE, position: 0)

checkpoints = CHECKPOINT_TITLES.each_with_index.map do |title, index|
  ensure_child.call(parent: plan, horizon: "project", title: title, position: index)
end

checkpoints.first.complete!

current = checkpoints[1]
steps = ensure_child.call(parent: current, horizon: "project", title: STEPS_TITLE, position: 0)

# Heal older seed shape: objective titles used to be sibling day goals.
legacy_titles = OBJECTIVES.map { |o| o[:title] }
steps.children.where(horizon: "day", title: legacy_titles).find_each(&:destroy!)

host = ensure_child.call(
  parent: steps,
  horizon: "day",
  title: HOST_TITLE,
  position: 0,
  scheduled_on: Date.current
)

OBJECTIVES.each_with_index do |attrs, index|
  task = host.practice_tasks.find_or_initialize_by(title: attrs[:title])
  task.user = demo_user
  task.position = index
  task.save!
  task.complete! if attrs[:complete]
end

# Cascade syncs day StrategyGoals → daily_todos (not PracticeTasks).
Strategy::CascadeToDaily.call(user: demo_user, life_area: area)

done = host.practice_tasks.count(&:completed?)
total = host.practice_tasks.size
puts "Mountain demo: #{JOURNEY_TITLE} (Money) — 5 checkpoints, Steps host '#{HOST_TITLE}' #{done}/#{total} objectives"
