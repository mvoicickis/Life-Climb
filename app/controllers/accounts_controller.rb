# frozen_string_literal: true

class AccountsController < ApplicationController
  skip_onboarding_check
  before_action :reject_impersonation!

  rate_limit to: 10, within: 3.minutes, only: :destroy, with: -> {
    stash_account_delete_sheet_error!("rate_limited")
    redirect_to settings_path(delete_account: 1)
  }

  def destroy
    unless current_user.authenticate(params[:password].to_s)
      stash_account_delete_sheet_error!("wrong_password")
      redirect_to settings_path(delete_account: 1) and return
    end

    result = Accounts::DestroyUser.call(user: current_user)
    unless result.ok?
      stash_account_delete_sheet_error!("stripe_blocked")
      redirect_to settings_path(delete_account: 1) and return
    end

    terminate_session
    redirect_to root_path, notice: t("account_delete.deleted_notice")
  end

  private

  def reject_impersonation!
    return unless impersonating?

    redirect_to settings_path, alert: t("account_delete.not_while_impersonating")
  end

  def stash_account_delete_sheet_error!(key)
    session[:account_delete_sheet_error] = key
  end
end
