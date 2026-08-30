# frozen_string_literal: true

module AdminImpersonationReadOnly
  extend ActiveSupport::Concern

  IMPERSONATION_MUTATION_ALLOWLIST = [
    %w[admin/impersonations destroy],
    %w[locales update]
  ].freeze

  included do
    before_action :reject_mutations_while_impersonating!, if: :impersonating?
    helper_method :read_only_impersonation?
  end

  def read_only_impersonation?
    impersonating?
  end

  private

  def reject_mutations_while_impersonating!
    return unless request.post? || request.patch? || request.put? || request.delete?
    return if IMPERSONATION_MUTATION_ALLOWLIST.include?([ controller_path, action_name ])

    message = t("admin.impersonation.read_only_blocked")
    respond_to do |format|
      format.html { redirect_back fallback_location: dashboard_path, alert: message, status: :see_other }
      format.turbo_stream { redirect_to dashboard_path, alert: message, status: :see_other }
      format.json { render json: { error: message }, status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
