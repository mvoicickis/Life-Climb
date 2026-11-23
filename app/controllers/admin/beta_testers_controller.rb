# frozen_string_literal: true

module Admin
  class BetaTestersController < BaseController
    def index
      @roster = BetaTestersRoster.call
    end

    def create
      result = BetaTestersImport.call(params.fetch(:emails, ""))
      redirect_to admin_beta_testers_path,
                  notice: t(
                    "admin.beta_testers.import_summary",
                    added: result.added,
                    already_there: result.already_there,
                    no_account: result.no_account,
                    invalid: result.invalid
                  )
    end

    def invite
      user = User.excluding_privileged.find(params[:user_id])
      user.update!(beta_invited_at: Time.current)
      redirect_to admin_beta_testers_path, notice: t("admin.beta_testers.invited", email: user.email_address)
    end

    def uninvite
      user = User.excluding_privileged.find(params[:user_id])
      user.update!(beta_invited_at: nil)
      redirect_to admin_beta_testers_path, notice: t("admin.beta_testers.uninvited", email: user.email_address)
    end
  end
end
