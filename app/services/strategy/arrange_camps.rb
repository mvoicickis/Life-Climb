# frozen_string_literal: true

module Strategy
  # Rewrites plan camp stage (contiguous 0..G-1) and global position from grouped order.
  class ArrangeCamps
    class Invalid < StandardError; end

    def self.call(user:, plan:, groups:)
      new(user: user, plan: plan, groups: groups).call
    end

    def initialize(user:, plan:, groups:)
      @user = user
      @plan = plan
      @groups = normalize_groups(groups)
    end

    def call
      validate!
      apply!
    end

    private

    def normalize_groups(groups)
      Array(groups).map do |entry|
        ids = entry.is_a?(Hash) ? entry[:camp_ids] || entry["camp_ids"] : entry
        { camp_ids: Array(ids).map(&:to_i).reject(&:zero?) }
      end.reject { |g| g[:camp_ids].empty? }
    end

    def plan_camps
      @plan_camps ||= StrategyGoal.where(parent_id: @plan.id).for_kind("project").not_holding.order(:position, :id).to_a
    end

    def validate!
      raise Invalid, "plan_missing" if @plan.blank? || !@plan.plan?
      raise Invalid, "not_authorized" unless @plan.user_id == @user.id

      payload_ids = @groups.flat_map { |g| g[:camp_ids] }
      raise Invalid, "duplicate_camp_id" if payload_ids.uniq.size != payload_ids.size

      expected_ids = plan_camps.map(&:id).sort
      raise Invalid, "camp_mismatch" unless expected_ids == payload_ids.sort
    end

    def apply!
      by_id = plan_camps.index_by(&:id)
      touch = Time.current
      global_position = 0

      StrategyGoal.transaction do
        @groups.each_with_index do |group, stage|
          group[:camp_ids].each do |camp_id|
            camp = by_id[camp_id]
            raise Invalid, "unknown_camp" if camp.blank?

            camp.update_columns(stage: stage, position: global_position, updated_at: touch)
            global_position += 1
          end
        end
      end
    end
  end
end
