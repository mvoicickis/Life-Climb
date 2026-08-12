# frozen_string_literal: true

namespace :weekly_planner do
  desc "Repair strategy_goals/daily_todos titles dumped as {\"title\" => \"...\"}. DRY_RUN=1 (default) or DRY_RUN=0 to apply."
  task repair_hash_titles: :environment do
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"
    result = Strategy::WeeklyPlanner::RepairHashTitles.call(dry_run: dry_run)
    puts "dry_run=#{result.dry_run}"
    puts "strategy_goals matched=#{result.goals_matched} updated=#{result.goals_updated}"
    puts "daily_todos matched=#{result.todos_matched} updated=#{result.todos_updated}"
  end
end
