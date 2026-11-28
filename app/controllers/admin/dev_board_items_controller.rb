# frozen_string_literal: true

module Admin
  class DevBoardItemsController < BaseController
    before_action :load_admin_owners, only: %i[index create update move]
    before_action :set_dev_board_item, only: %i[move update destroy]

    def index
      @report_item = DevBoardItem.new
      @open_report_modal = false

      if DevBoardSamplePreview.enabled?(params[:preview])
        load_sample_preview!
      else
        load_board_from_db!
      end
    end

    def create
      @report_item = DevBoardItem.new(dev_board_item_params)
      @report_item.status = :idea
      @report_item.reported_by = current_user
      ensure_owner_is_admin!

      if @report_item.errors.empty? && @report_item.save
        redirect_to admin_dev_board_items_path, notice: t("admin.dev_board.report.created")
        return
      end

      @open_report_modal = true
      load_board_from_db!
      render :index, status: :unprocessable_entity
    end

    def update
      @report_item = @item
      @report_item.assign_attributes(dev_board_item_params)
      ensure_owner_is_admin!

      if @report_item.errors.empty? && @report_item.save
        redirect_to admin_dev_board_items_path, notice: t("admin.dev_board.report.updated")
        return
      end

      @open_report_modal = true
      load_board_from_db!
      render :index, status: :unprocessable_entity
    end

    def destroy
      @item.destroy!
      redirect_to admin_dev_board_items_path, notice: t("admin.dev_board.delete.deleted")
    end

    def move
      if @item.move!(
        to: params[:to],
        actor: current_user,
        admins: @admin_owners.to_a,
        check_note: params[:check_note],
        column: params[:column]
      )
        redirect_to admin_dev_board_items_path, notice: t("admin.dev_board.moves.success")
        return
      end

      redirect_to admin_dev_board_items_path, alert: @item.errors.full_messages.to_sentence
    end

    private

    def set_dev_board_item
      @item = DevBoardItem.find(params[:id])
    end

    def load_admin_owners
      @admin_owners = User.where(admin: true).order(:id)
    end

    def dev_board_item_params
      params.require(:dev_board_item).permit(
        :title,
        :description,
        :kind,
        :priority,
        :owner_id,
        :reporter_note
      )
    end

    def ensure_owner_is_admin!
      record = @report_item
      owner_id = record.owner_id.to_i
      return if owner_id.positive? && @admin_owners.any? { |user| user.id == owner_id }

      record.errors.add(:owner, t("admin.dev_board.report.owner_invalid"))
    end

    def load_sample_preview!
      admins = @admin_owners.limit(2).to_a
      data = DevBoardSamplePreview.build(users: admins)
      @columns = data[:columns]
    end

    def load_board_from_db!
      grouped = DevBoardItem
        .includes(:owner, :reported_by, :work_owner)
        .column_sorted
        .group_by(&:status)

      @columns = DevBoardItem::COLUMN_STATUSES.index_with { |status| grouped[status] || [] }
    end
  end
end