# frozen_string_literal: true

module Strategy
  # After "Not yet" on a project check, queue a next-angle prompt on Today.
  class BattleAngleQueue
    SESSION_KEY = :battle_angle_project_id

    def self.enqueue(session:, project_id:)
      id = project_id.to_i
      return if id.zero?

      session[SESSION_KEY] = id
    end

    def self.project_for(user:, session:)
      id = session[SESSION_KEY].to_i
      return if id.zero?

      project = user.strategy_goals.find_by(id: id, horizon: "project")
      if project.blank? || project.completed_at.present?
        clear(session: session)
        return
      end

      project
    end

    def self.clear(session:)
      session.delete(SESSION_KEY)
    end
  end
end
