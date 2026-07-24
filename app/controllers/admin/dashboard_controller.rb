module Admin
  class DashboardController < BaseController
    def show
      @users_count = User.count
      @feedbacks_count = Feedback.count
      @feedbacks = Feedback.includes(:user).newest_first.limit(100)
      @recent_users = User.order(created_at: :desc).limit(20)
    end
  end
end
