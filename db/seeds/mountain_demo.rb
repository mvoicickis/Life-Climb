# frozen_string_literal: true

# Idempotent Money-focused Mountain demo for demo@lifepoints.test.
# Safe to re-run: find-or-create by title + parent; complete! only when open.
#
# Quest Space counts PracticeTask rows on one host day
# (Strategy::EnsureFolderQuest::HOST_TITLE), not sibling day StrategyGoals.
# Stress data: 9 path checkpoints, longer checklist, second locked-camp folder,
# and one empty locked checkpoint for empty-state checks.

demo_user = User.find_by!(email_address: "demo@lifepoints.test")

JOURNEY_TITLE = "Reach $10k/month with LifePoints"
PLAN_TITLE = "Main path"
STEPS_TITLE = "Steps"
PLAYBOOKS_TITLE = "Playbooks"
HOST_TITLE = Strategy::EnsureFolderQuest::HOST_TITLE

# #1 done, #2 active, #3–9 locked.
# #3 gets a nested leaf (Playbooks). #4 stays empty (no child projects).
# #7 has a deliberately long title for truncation stress.
CHECKPOINT_TITLES = [
  "Nail the MVP experience",
  "Launch to first 100 users",
  "Build a referral loop",
  "Launch a paid tier",
  "Scale to 1,000 subscribers",
  "Hire first customer success hire",
  "Negotiate enterprise pilots with three mid-market finance teams",
  "Expand into a second vertical market",
  "Open a public roadmap and changelog"
].freeze

STEPS_OBJECTIVES = [
  { title: "Fix onboarding drop-off", complete: true },
  { title: "Add a referral share button", complete: true },
  { title: "Post in 3 founder communities", complete: false },
  { title: "Set up basic analytics", complete: false },
  { title: "Record a 60-second demo clip", complete: true },
  { title: "Email 10 warm intros this week", complete: false },
  { title: "Ship pricing page draft", complete: false }
].freeze

PLAYBOOKS_OBJECTIVES = [
  { title: "Draft invite email templates", complete: true },
  { title: "Map double-sided referral rewards", complete: false },
  { title: "List 5 partner communities to test", complete: false }
].freeze

ensure_objectives = lambda do |host, objectives|
  objectives.each_with_index do |attrs, index|
    task = host.practice_tasks.find_or_initialize_by(title: attrs[:title])
    task.user = demo_user
    task.position = index
    task.save!
    task.complete! if attrs[:complete]
  end
end

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

# --- Checkpoint #2 (active): Steps leaf + long checklist ---
current = checkpoints[1]
steps = ensure_child.call(parent: current, horizon: "project", title: STEPS_TITLE, position: 0)

# Heal older seed shape: objective titles used to be sibling day goals.
legacy_titles = STEPS_OBJECTIVES.map { |o| o[:title] }
steps.children.where(horizon: "day", title: legacy_titles).find_each(&:destroy!)

steps_host = ensure_child.call(
  parent: steps,
  horizon: "day",
  title: HOST_TITLE,
  position: 0,
  scheduled_on: Date.current
)
ensure_objectives.call(steps_host, STEPS_OBJECTIVES)

# --- Checkpoint #3 (locked): nested Playbooks leaf + short checklist ---
locked_with_folder = checkpoints[2]
playbooks = ensure_child.call(
  parent: locked_with_folder,
  horizon: "project",
  title: PLAYBOOKS_TITLE,
  position: 0
)
playbooks_host = ensure_child.call(
  parent: playbooks,
  horizon: "day",
  title: HOST_TITLE,
  position: 0,
  scheduled_on: Date.current
)
ensure_objectives.call(playbooks_host, PLAYBOOKS_OBJECTIVES)

# --- Checkpoint #4 (locked): intentionally empty — no child projects ---
# (do not create Steps / host under checkpoints[3])

# Cascade syncs day StrategyGoals → daily_todos (not PracticeTasks).
Strategy::CascadeToDaily.call(user: demo_user, life_area: area)

steps_done = steps_host.practice_tasks.reload.count { |t| t.completed? }
play_done = playbooks_host.practice_tasks.reload.count { |t| t.completed? }
puts "Mountain demo: #{JOURNEY_TITLE} (Money) — #{checkpoints.size} checkpoints"
puts "  #2 Steps '#{HOST_TITLE}': #{steps_done}/#{STEPS_OBJECTIVES.size} objectives"
puts "  #3 Playbooks '#{HOST_TITLE}': #{play_done}/#{PLAYBOOKS_OBJECTIVES.size} objectives"
puts "  #4 '#{checkpoints[3].title}': empty (no nested folders)"
puts "  #7 long title (#{CHECKPOINT_TITLES[6].length} chars): #{CHECKPOINT_TITLES[6]}"
