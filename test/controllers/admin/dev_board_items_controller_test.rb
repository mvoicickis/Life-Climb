# frozen_string_literal: true

require "test_helper"

module Admin
  class DevBoardItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:one)
    end

    test "non admin is redirected with access denied" do
      sign_in_as @user
      get admin_dev_board_items_path

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "guest is sent to sign in" do
      get admin_dev_board_items_path
      assert_redirected_to new_session_path
    end

    test "admin can open dev board" do
      DevBoardItem.create!(
        owner: @admin,
        reported_by: @user,
        title: "Stats page locks on old calendar month",
        kind: :bug,
        priority: :urgent,
        status: :todo
      )

      sign_in_as @admin
      get admin_dev_board_items_path

      assert_response :success
      assert_select "h1", text: /Dev board/
      assert_select ".lp-dev-board__column", count: 4
      assert_match(/Stats page locks on old calendar month/, response.body)
      assert_match(/To do/, response.body)
      assert_match(/Needs check/, response.body)
    end
  end
end
