class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :goals_current_by_user_id
  delegate :user, to: :session, allow_nil: true
end
