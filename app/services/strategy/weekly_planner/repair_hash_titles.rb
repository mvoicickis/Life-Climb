# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Repairs strategy_goals / daily_todos titles corrupted as Hash dumps
    # (e.g. {"title" => "Get a job"}). Idempotent — already-fixed rows no-op.
    class RepairHashTitles
      Result = Struct.new(:goals_matched, :goals_updated, :todos_matched, :todos_updated, :dry_run, keyword_init: true)

      # Broad SQL prefilter (SQLite + Postgres); exact shape checked in Ruby.
      LIKE_PATTERN = '%{"title"%'

      def self.call(dry_run: true, logger: Rails.logger)
        new(dry_run:, logger:).call
      end

      def initialize(dry_run: true, logger: Rails.logger)
        @dry_run = dry_run
        @logger = logger
      end

      def call
        goal_rows = corrupted_rows(StrategyGoal)
        todo_rows = corrupted_rows(DailyTodo)

        goals_matched = goal_rows.size
        todos_matched = todo_rows.size
        goals_updated = 0
        todos_updated = 0

        @logger.info("[weekly_planner:repair_hash_titles] dry_run=#{@dry_run} goals=#{goals_matched} todos=#{todos_matched}")

        goal_rows.each do |goal|
          fixed = ItemTitle.extract(goal.title)
          next if fixed.blank? || fixed == goal.title

          @logger.info("[weekly_planner:repair_hash_titles] strategy_goal##{goal.id}: #{goal.title.inspect} -> #{fixed.inspect}")
          next if @dry_run

          goal.update_columns(title: fixed, updated_at: Time.current)
          goals_updated += 1
        end

        todo_rows.each do |todo|
          fixed = ItemTitle.extract(todo.title)
          next if fixed.blank? || fixed == todo.title

          @logger.info("[weekly_planner:repair_hash_titles] daily_todo##{todo.id}: #{todo.title.inspect} -> #{fixed.inspect}")
          next if @dry_run

          todo.update_columns(title: fixed, updated_at: Time.current)
          todos_updated += 1
        end

        Result.new(
          goals_matched: goals_matched,
          goals_updated: goals_updated,
          todos_matched: todos_matched,
          todos_updated: todos_updated,
          dry_run: @dry_run
        )
      end

      private

      def corrupted_rows(model)
        model.where("title LIKE ?", LIKE_PATTERN).find_each.select { |row| ItemTitle.corrupted?(row.title) }
      end
    end
  end
end
