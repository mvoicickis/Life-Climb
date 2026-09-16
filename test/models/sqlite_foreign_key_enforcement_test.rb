# frozen_string_literal: true

require "test_helper"

# Gate: CI test DB is SQLite. If FKs are not enforced, a soft delete-goal
# test would pass while production Postgres would raise. Prove FKs fire first.
class SqliteForeignKeyEnforcementTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    @area = @user.life_areas.first || @user.life_areas.create!(key: "career", number: 9)
  end

  test "sqlite rejects deleting a parent strategy_goal while a child still references it" do
    skip "Not SQLite — this gate is for CI's sqlite3 adapter" unless sqlite_adapter?

    parent = @user.strategy_goals.create!(
      life_area: @area, horizon: "goal", title: "FK parent", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, parent: parent, horizon: "plan", title: "FK child", position: 0
    )

    error = assert_raises(ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid) do
      # Bypass dependent: :destroy so only the DB constraint can protect the child.
      StrategyGoal.where(id: parent.id).delete_all
    end

    assert_match(/foreign key|FOREIGN KEY|constraint/i, error.message)
    assert StrategyGoal.exists?(parent.id), "parent should still exist when FK blocked the delete"
  end

  private

  def sqlite_adapter?
    ActiveRecord::Base.connection.adapter_name.match?(/sqlite/i)
  end
end
