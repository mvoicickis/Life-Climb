# frozen_string_literal: true

module Battles
  # Completes today's battle from a notification action.
  # Does not fabricate a battle when none exists — returns nothing_to_mark instead.
  class MarkDoneFromNotification
    class Error < StandardError; end

    Result = Struct.new(:todo, :title, :nothing_to_mark, keyword_init: true)

    def self.call(user:, session:, category: nil)
      new(user: user, session: session, category: category).call
    end

    def initialize(user:, session:, category: nil)
      @user = user
      @session = session
      @category = category
    end

    def call
      todo = completable_todo_for_today
      if todo.nil?
        return Result.new(todo: nil, title: nil, nothing_to_mark: true)
      end

      CompleteTodo.call(todo: todo, user: @user, session: @session)
      Result.new(todo: todo.reload, title: todo.title, nothing_to_mark: false)
    end

    private

    def completable_todo_for_today
      @user.daily_todos.for_day(Date.current).incomplete.ordered.find do |todo|
        !requires_amount?(todo)
      end
    end

    def requires_amount?(todo)
      day = todo.strategy_goal
      return false if day.blank?
      return false if day.practice_tasks.any?

      day.quantified_path_project.present?
    end
  end
end
