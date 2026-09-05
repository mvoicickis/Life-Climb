# frozen_string_literal: true

module Battles
  # Surfaces an existing Mountain battle on Today without creating a new goal.
  class SurfaceOnToday
    class Error < StandardError; end

    Result = Struct.new(:todo, :battle, :title, keyword_init: true)

    def self.call(user:, battle:)
      new(user:, battle:).call
    end

    def initialize(user:, battle:)
      @user = user
      @battle = battle
    end

    def call
      raise Error, I18n.t("notifications.actions.unauthorized") if @battle.blank?
      raise Error, I18n.t("notifications.actions.unauthorized") unless @battle.user_id == @user.id
      raise Error, I18n.t("notifications.actions.unauthorized") unless @battle.day?

      todo = Strategy::CascadeToDaily.sync_goal!(user: @user, goal: @battle)
      raise Error, I18n.t("notifications.actions.mark_done_none") if todo.blank?

      Result.new(todo: todo, battle: @battle, title: @battle.title)
    end
  end
end
