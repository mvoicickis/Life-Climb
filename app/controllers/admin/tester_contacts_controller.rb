# frozen_string_literal: true

module Admin
  class TesterContactsController < BaseController
    before_action :set_user

    def edit
      @contact = TesterContact.find_or_initialize_by(user_id: @user.id)
      @contact.last_contacted_on ||= Date.current
    end

    def update
      @contact = TesterContact.find_or_initialize_by(user_id: @user.id)
      @contact.assign_attributes(contact_params)
      @contact.updated_by = current_user

      if @contact.save
        redirect_to admin_testers_path(filter: Testers::FILTER_EVERYONE, anchor: "tester-#{@user.id}"),
                    notice: t("admin.testers.contact_saved")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.excluding_privileged.find(params[:user_id])
    end

    def contact_params
      params.require(:tester_contact).permit(:channel, :details, :last_contacted_on, :note)
    end
  end
end
