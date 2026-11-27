# frozen_string_literal: true

module Admin
  class DevBoardItemsController < BaseController
    def index
      grouped = DevBoardItem
        .includes(:owner, :reported_by)
        .column_sorted
        .group_by(&:status)

      @columns = DevBoardItem::COLUMN_STATUSES.index_with { |status| grouped[status] || [] }
      @later_items = grouped[DevBoardItem::LATER_STATUS] || []
    end
  end
end
