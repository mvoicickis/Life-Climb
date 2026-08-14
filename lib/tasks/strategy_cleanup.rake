# frozen_string_literal: true

namespace :strategy do
  desc "READ-ONLY report of journeys with more than one destination (root goal) " \
       "or more than one Plan. Changes nothing — run and approve before the collapse migration."
  task one_goal_report: :environment do
    puts "== One-goal / one-plan report =="
    puts "Generated at #{Time.current.iso8601}"
    puts "(read-only — no data is changed)"
    puts

    roots = StrategyGoal.for_kind("goal").roots.order(:position, :id).to_a
    plans = StrategyGoal.for_kind("plan").not_holding.order(:position, :id).to_a

    # 1. Journeys with 2+ non-holding root goals (goals never hold).
    roots_by_journey = roots.group_by(&:life_journey_id)
    multi_goal = roots_by_journey.select { |journey_id, list| journey_id.present? && list.size > 1 }
    puts "Journeys with 2+ destinations (root goals): #{multi_goal.size}"
    multi_goal.each do |journey_id, list|
      puts "  journey ##{journey_id} (user ##{list.first.user_id}): #{list.size} destinations"
      list.each { |g| puts "    - goal ##{g.id} #{g.title.inspect}" }
    end
    puts

    # 2. Goals with 2+ non-holding Plans.
    plans_by_goal = plans.group_by(&:parent_id)
    multi_plan = plans_by_goal.select { |_goal_id, list| list.size > 1 }
    puts "Goals with 2+ Plans: #{multi_plan.size}"
    multi_plan.each do |goal_id, list|
      puts "  goal ##{goal_id} (user ##{list.first.user_id}): #{list.size} plans"
      list.each { |p| puts "    - plan ##{p.id} #{p.title.inspect}#{p.completed? ? ' [complete]' : ''}" }
    end
    puts

    # 3. Root goals missing life_journey_id (the migration will backfill these).
    orphan_roots = roots.select { |g| g.life_journey_id.blank? }
    puts "Root goals with no life_journey_id (migration will backfill): #{orphan_roots.size}"
    orphan_roots.each do |g|
      puts "  - goal ##{g.id} (user ##{g.user_id}, area ##{g.life_area_id}) #{g.title.inspect}"
    end
    puts

    # 4. Sibling-adopt preview: journeys where the surviving destination has no
    #    Plan but a sibling destination does, so the migration would move a Plan
    #    the user wrote under a different destination onto the survivor.
    plan_goal_ids = plans.map(&:parent_id).to_set
    adopt = []
    multi_goal.each do |journey_id, list|
      surviving = list.min_by { |g| [ g.position.to_i, g.id ] }
      next if plan_goal_ids.include?(surviving.id)

      donor = list.find { |g| g.id != surviving.id && plan_goal_ids.include?(g.id) }
      adopt << [ journey_id, surviving, donor ] if donor
    end
    puts "Journeys where the migration would ADOPT a Plan from a sibling destination: #{adopt.size}"
    adopt.each do |journey_id, surviving, donor|
      puts "  journey ##{journey_id}: surviving goal ##{surviving.id} has no Plan; " \
           "would adopt a Plan from sibling goal ##{donor.id}"
    end
    puts

    puts "== End of report (nothing was changed) =="
  end
end
