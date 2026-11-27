# frozen_string_literal: true

module Admin
  class DevBoardItemsController < BaseController
    def index
      if DevBoardSamplePreview.enabled?(params[:preview])
        load_sample_preview!
      else
        load_board_from_db!
      end
    end

    private

    def load_sample_preview!
      admins = User.where(admin: true).order(:id).limit(2).to_a
      data = DevBoardSamplePreview.build(users: admins)
      @columns = data[:columns]
      @later_items = data[:later_items]
    end

    def load_board_from_db!
      grouped = DevBoardItem
        .includes(:owner, :reported_by)
        .column_sorted
        .group_by(&:status)

      @columns = DevBoardItem::COLUMN_STATUSES.index_with { |status| grouped[status] || [] }
      @later_items = grouped[DevBoardItem::LATER_STATUS] || []
    end
  end
end
