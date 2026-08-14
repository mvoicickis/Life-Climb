# frozen_string_literal: true

module Strategy
  # Queues open parent projects for the "Did you finish this project?" check on Today.
  class ProjectCheckQueue
    SESSION_KEY = :project_check_ids

    def self.enqueue(session:, project_ids:)
      ids = Array(project_ids).map(&:to_i).reject(&:zero?)
      return if ids.empty?

      session[SESSION_KEY] = ((session[SESSION_KEY] || []) + ids).uniq
    end

    def self.next_for(user:, session:)
      ids = Array(session[SESSION_KEY]).map(&:to_i)
      return if ids.empty?

      project = user.strategy_goals.where(id: ids, horizon: "project").not_holding.incomplete.ordered.first
      unless project
        session.delete(SESSION_KEY)
        return
      end

      project
    end

    def self.dequeue(session:, project_id:)
      ids = Array(session[SESSION_KEY]).map(&:to_i) - [ project_id.to_i ]
      if ids.empty?
        session.delete(SESSION_KEY)
      else
        session[SESSION_KEY] = ids
      end
    end

    def self.from_battles(battles)
      Array(battles).filter_map do |battle|
        next unless battle&.day?
        next if battle.parent.blank? || !battle.parent.project?
        next if battle.parent.holding?
        next if battle.parent.completed?

        battle.parent_id
      end.uniq
    end
  end
end
