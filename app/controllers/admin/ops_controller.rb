# frozen_string_literal: true

module Admin
  class OpsController < BaseController
    def show
      @maintenance_mode = AppSetting.maintenance_mode?
      @announcement_banner = AppSetting.announcement_banner.to_s
      @feature_feedback_inbox = AppSetting.truthy?(AppSetting::KEYS[:feature_feedback_inbox])
      @feature_export_stats = AppSetting.truthy?(AppSetting::KEYS[:feature_export_stats])
    end

    def update
      AppSetting.write(AppSetting::KEYS[:maintenance_mode], ActiveModel::Type::Boolean.new.cast(params[:maintenance_mode]) ? "true" : "false")
      AppSetting.write(AppSetting::KEYS[:announcement_banner], params[:announcement_banner].to_s.strip.presence)
      AppSetting.write(AppSetting::KEYS[:feature_feedback_inbox], ActiveModel::Type::Boolean.new.cast(params[:feature_feedback_inbox]) ? "true" : "false")
      AppSetting.write(AppSetting::KEYS[:feature_export_stats], ActiveModel::Type::Boolean.new.cast(params[:feature_export_stats]) ? "true" : "false")

      redirect_to admin_ops_path, notice: t("admin.ops.updated")
    end
  end
end
