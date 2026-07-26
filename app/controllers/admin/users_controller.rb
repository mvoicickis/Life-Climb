# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show edit update destroy promote demote]

    def index
      scope = User.all
      scope = apply_search(scope)
      scope = apply_sort(scope)
      @users = scope.limit(200)
      @query = params[:q].to_s.strip
      @sort = params[:sort].presence || "newest"

      respond_to do |format|
        format.html
        format.csv { send_data export_csv(scope.limit(5_000)), filename: "lifepoints-users-#{Date.current}.csv" }
      end
    end

    def show
      @journeys = @user.life_journeys.order(created_at: :desc).limit(20)
      @goals = @user.strategy_goals.for_kind("goal").order(created_at: :desc).limit(20)
      @plans = @user.strategy_goals.for_kind("plan").order(created_at: :desc).limit(20)
      @projects = @user.strategy_goals.for_kind("project").order(created_at: :desc).limit(20)
      @battles = @user.strategy_goals.battles.order(created_at: :desc).limit(20)
      @missions = @user.missions.order(created_at: :desc).limit(20)
      @ledgers = @user.life_point_ledgers.order(created_at: :desc).limit(20)
      @sessions = @user.sessions.order(updated_at: :desc).limit(10)
      @last_seen_at = @user.sessions.maximum(:updated_at)
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: t("admin.users.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user || @user.id == session[:admin_impersonator_id].to_i
        redirect_to admin_users_path, alert: t("admin.users.cannot_delete_self") and return
      end

      # Break circular FK: users.focus_building_id → buildings → users
      @user.update_columns(focus_building_id: nil)
      @user.destroy!
      redirect_to admin_users_path, notice: t("admin.users.deleted")
    end

    def promote
      @user.update!(admin: true)
      redirect_back fallback_location: admin_user_path(@user), notice: t("admin.users.promoted")
    end

    def demote
      if @user == current_user
        redirect_back fallback_location: admin_user_path(@user), alert: t("admin.users.cannot_demote_self") and return
      end

      @user.update!(admin: false)
      redirect_back fallback_location: admin_user_path(@user), notice: t("admin.users.demoted")
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email_address, :home_stat_count)
    end

    def apply_search(scope)
      q = params[:q].to_s.strip
      return scope if q.blank?

      like = "%#{ActiveRecord::Base.sanitize_sql_like(q.downcase)}%"
      scope.where("LOWER(email_address) LIKE :q OR LOWER(COALESCE(name, '')) LIKE :q", q: like)
    end

    def apply_sort(scope)
      case params[:sort].to_s
      when "oldest" then scope.order(created_at: :asc)
      when "points" then scope.order(total_points: :desc, id: :desc)
      when "active"
        scope.select("users.*, (SELECT MAX(sessions.updated_at) FROM sessions WHERE sessions.user_id = users.id) AS last_seen_at")
             .order(Arel.sql("last_seen_at IS NULL, last_seen_at DESC"), id: :desc)
      when "admin" then scope.order(admin: :desc, created_at: :desc)
      else scope.order(created_at: :desc)
      end
    end

    def export_csv(scope)
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << %w[id name email life_points strategy_points admin onboarding_completed_at created_at]
        scope.find_each do |user|
          csv << [
            user.id,
            user.name,
            user.email_address,
            user.total_points,
            user.strategy_points,
            user.admin?,
            user.onboarding_completed_at,
            user.created_at
          ]
        end
      end
    end
  end
end
