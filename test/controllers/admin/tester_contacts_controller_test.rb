# frozen_string_literal: true

require "test_helper"

module Admin
  class TesterContactsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
    end

    test "non admin cannot edit contact" do
      sign_in_as @user
      get edit_admin_tester_contact_path(@user)

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "non admin cannot update contact" do
      sign_in_as @user
      patch admin_tester_contact_path(@user), params: {
        tester_contact: {
          channel: "whatsapp",
          details: "353872346580",
          last_contacted_on: "2026-11-18",
          note: "asked about first battle"
        }
      }

      assert_redirected_to dashboard_path
      assert_nil TesterContact.find_by(user_id: @user.id)
    end

    test "admin can save note and date" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        sign_in_as @admin

        patch admin_tester_contact_path(@user), params: {
          tester_contact: {
            channel: "whatsapp",
            details: "+00 353 87 234 6580",
            last_contacted_on: "2026-11-18",
            note: "asked about first battle"
          }
        }

        assert_redirected_to admin_testers_path(filter: Testers::FILTER_EVERYONE, anchor: "tester-#{@user.id}")
        contact = TesterContact.find_by!(user_id: @user.id)
        assert_equal "whatsapp", contact.channel
        assert_equal "+00 353 87 234 6580", contact.details
        assert_equal Date.new(2026, 11, 18), contact.last_contacted_on
        assert_equal "asked about first battle", contact.note
        assert_equal @admin.id, contact.updated_by_id
      end
    end

    test "edit form defaults last contacted to today" do
      travel_to Time.zone.parse("2026-11-18 12:00:00") do
        sign_in_as @admin
        get edit_admin_tester_contact_path(@user)

        assert_response :success
        assert_select "input[name='tester_contact[last_contacted_on]'][value=?]", "2026-11-18"
      end
    end
  end
end
