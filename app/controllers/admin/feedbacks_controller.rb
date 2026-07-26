# frozen_string_literal: true

module Admin
  class FeedbacksController < BaseController
    def index
      @feedbacks = Feedback.includes(:user).newest_first.limit(200)
    end

    def destroy
      Feedback.find(params[:id]).destroy!
      redirect_to admin_feedbacks_path, notice: t("admin.feedbacks.deleted")
    end
  end
end
