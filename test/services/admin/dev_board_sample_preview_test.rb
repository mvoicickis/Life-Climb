# frozen_string_literal: true

require "test_helper"

module Admin
  class DevBoardSamplePreviewTest < ActiveSupport::TestCase
    test "enabled only in development with sample param" do
      assert_not DevBoardSamplePreview.enabled?("sample")
      assert_not DevBoardSamplePreview.enabled?("other")
    end

    test "build returns eight in-memory items across columns" do
      users = [ users(:admin), users(:one) ]
      data = DevBoardSamplePreview.build(users: users)
      total = data[:columns].values.flatten.size

      assert_equal 8, total
      assert_equal 2, data[:columns]["idea"].size
      assert_equal 1, data[:columns]["todo"].size
      assert_equal 2, data[:columns]["doing"].size
      assert_equal 2, data[:columns]["needs_check"].size
      assert_equal 1, data[:columns]["done"].size
      assert data[:columns]["todo"].first.title.include?("Stats page")
      assert_not data[:columns]["todo"].first.persisted?
    end
  end
end
