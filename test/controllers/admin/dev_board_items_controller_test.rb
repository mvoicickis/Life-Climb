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

    test "preview sample is ignored in test" do
      sign_in_as @admin
      get admin_dev_board_items_path, params: { preview: "sample" }

      assert_response :success
      assert_no_match(/Memory leak on Render/, response.body)
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
      assert_select ".lp-dev-board__column", count: 5
      assert_match(/Stats page locks on old calendar month/, response.body)
      assert_match(/This week/, response.body)
      assert_match(/Needs check/, response.body)
    end

    test "admin can create a dev board item" do
      sign_in_as @admin

      assert_difference -> { DevBoardItem.count }, 1 do
        post admin_dev_board_items_path, params: {
          dev_board_item: {
            title: "Splash screen stuck on old build",
            kind: "bug",
            priority: "urgent",
            owner_id: @admin.id
          }
        }
      end

      assert_redirected_to admin_dev_board_items_path
      assert_equal "Added to the board.", flash[:notice]

      item = DevBoardItem.order(:id).last
      assert_equal "idea", item.status
      assert_equal @admin, item.owner
      assert_equal @admin, item.reported_by
      assert_equal "Splash screen stuck on old build", item.title
    end

    test "create rejects blank title" do
      sign_in_as @admin

      assert_no_difference -> { DevBoardItem.count } do
        post admin_dev_board_items_path, params: {
          dev_board_item: {
            title: "",
            kind: "bug",
            priority: "important",
            owner_id: @admin.id
          }
        }
      end

      assert_response :unprocessable_entity
      assert_match(/Title.*blank/i, response.body)
    end

    test "non admin cannot create dev board item" do
      sign_in_as @user

      assert_no_difference -> { DevBoardItem.count } do
        post admin_dev_board_items_path, params: {
          dev_board_item: {
            title: "Should not save",
            kind: "bug",
            priority: "important",
            owner_id: @admin.id
          }
        }
      end

      assert_redirected_to dashboard_path
      follow_redirect!
      assert_match(/Access denied/i, flash[:alert].to_s + response.body)
    end

    test "create rejects non admin owner" do
      sign_in_as @admin

      assert_no_difference -> { DevBoardItem.count } do
        post admin_dev_board_items_path, params: {
          dev_board_item: {
            title: "Wrong owner",
            kind: "bug",
            priority: "important",
            owner_id: @user.id
          }
        }
      end

      assert_response :unprocessable_entity
      assert_match(/team admin/i, response.body)
    end

    test "non admin cannot move dev board item" do
      item = DevBoardItem.create!(
        owner: @admin,
        reported_by: @admin,
        title: "Lock card",
        kind: :bug,
        priority: :important,
        status: :todo
      )

      sign_in_as @user
      patch move_admin_dev_board_item_path(item), params: { to: "start" }

      assert_redirected_to dashboard_path
      assert item.reload.todo?
    end

    test "admin can move dev board item via patch" do
      item = DevBoardItem.create!(
        owner: @admin,
        reported_by: @admin,
        title: "Start me",
        kind: :bug,
        priority: :important,
        status: :todo
      )

      sign_in_as @admin
      patch move_admin_dev_board_item_path(item), params: { to: "start" }

      assert_redirected_to admin_dev_board_items_path
      assert item.reload.doing?
    end
  end
end
