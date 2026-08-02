# frozen_string_literal: true

# Idempotent Money-focused Mountain demo for demo@lifepoints.test.
# Safe to re-run: find-or-create by title + parent; complete! only when open.

demo_user = User.find_by!(email_address: "demo@lifepoints.test")

JOURNEY_TITLE = "Reach $10k/month with LifePoints"
PLAN_TITLE = "Main path"
STEPS_TITLE = "Steps"

CHECKPOINT_TITLES = [
  "Nail the MVP experience",
  "Launch to first 100 users",
  "Build a referral loop",
  "Launch a paid tier",
  "Scale to 1,000 subscribers"
].freeze

BATTLES = [
  { title: "Fix onboarding drop-off", scheduled_on: Date.current - 2, complete: true },
  { title: "Add a referral share button", scheduled_on: Date.current - 1, complete: true },
  { title: "Post in 3 founder communities", scheduled_on: Date.current, complete: false },
  { title: "Set up basic analytics", scheduled_on: Date.current + 1, complete: false }
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
    goal.update!(position: position, life_journey: journey) if goal.position != position || goal.life_journey_id != journey.id
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

BATTLES.each_with_index do |attrs, index|
  battle = ensure_child.call(
    parent: steps,
    horizon: "day",
    title: attrs[:title],
    position: index,
    scheduled_on: attrs[:scheduled_on]
  )
  battle.update!(scheduled_on: attrs[:scheduled_on]) if battle.scheduled_on != attrs[:scheduled_on]
  battle.complete! if attrs[:complete]
end

Strategy::CascadeToDaily.call(user: demo_user, life_area: area)

puts "Mountain demo: #{JOURNEY_TITLE} (Money) — 5 checkpoints, Steps battles under ##{2}"
