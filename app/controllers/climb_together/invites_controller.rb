# frozen_string_literal: true

module ClimbTogether
  class InvitesController < ApplicationController
    allow_unauthenticated_access only: %i[ show accept ]
    skip_onboarding_check only: :show

    def show
      @token = params[:token].to_s
      @partnership = ClimbPartnership.find_by(token: @token)
      @state = invite_state(@partnership)
      @inviter = @partnership&.inviter
    end

    def accept
      token = params[:token].to_s
      stash_climb_invite_token!(token)

      unless authenticated?
        session[:return_to_after_authenticating] = climb_invite_path(token)
        redirect_to new_registration_path and return
      end

      begin
        partnership = Accept.call(user: current_user, token: token)
        clear_climb_invite_token!
        inviter_name = partnership.inviter.display_name
        redirect_to dashboard_path,
                    notice: t("climb_together.flash.accepted", name: inviter_name)
      rescue Error
        redirect_to climb_invite_path(token)
      end
    end

    private

    def invite_state(partnership)
      return :closed if partnership.blank?
      return :closed unless partnership.pending?
      return :closed if authenticated? && partnership.inviter_id == current_user.id
      return :closed if authenticated? && ClimbPartnership.active_for(current_user).exists?
      return :closed if ClimbPartnership.active_for(partnership.inviter).exists?

      :open
    end
  end
end
