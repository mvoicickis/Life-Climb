# frozen_string_literal: true

module Battles
  # Completes today's battle from a notification action — creates one first if needed.
  class MarkDoneFromNotification
    class Error < StandardError; end

    Result = Struct.new(:todo, :created, :title, keyword_init: true)

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
      created = false

      if todo.nil?
        added = QuickAddToday.call(user: @user, category: @category)
        todo = added.todo
        created = true
      end

      CompleteTodo.call(todo: todo, user: @user, session: @session)
      Result.new(todo: todo.reload, created: created, title: todo.title)
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
