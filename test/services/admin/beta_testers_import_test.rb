# frozen_string_literal: true

require "test_helper"

module Admin
  class BetaTestersImportTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      BetaTester.delete_all
    end

    test "mixed comma and newline paste adds emails and links user" do
      text = "one@example.com, ghost@example.com\nnew@example.com"

      result = BetaTestersImport.call(text)

      assert_equal 3, result.added
      assert_equal 0, result.already_there
      assert_equal 2, result.no_account
      assert_equal 0, result.invalid

      linked = BetaTester.find_by!(email: "one@example.com")
      assert_equal @user.id, linked.user_id
      assert_nil BetaTester.find_by!(email: "ghost@example.com").user_id
    end

    test "second paste with overlap only adds new ones" do
      BetaTestersImport.call("old@example.com\none@example.com")
      result = BetaTestersImport.call("one@example.com, fresh@example.com")

      assert_equal 1, result.added
      assert_equal 1, result.already_there
      assert_equal 1, result.no_account
      assert_equal 0, result.invalid
      assert_equal 3, BetaTester.count
    end

    test "invalid strings are skipped" do
      result = BetaTestersImport.call("not-an-email, fine@example.com, @@")

      assert_equal 1, result.added
      assert_equal 2, result.invalid
      assert_equal 1, result.no_account
      assert_equal 1, BetaTester.count
    end

    test "backfills user_id on existing row when user signs up later" do
      BetaTestersImport.call("one@example.com")
      row = BetaTester.find_by!(email: "one@example.com")
      row.update_columns(user_id: nil, updated_at: Time.current)

      BetaTestersImport.call("one@example.com")

      assert_equal @user.id, row.reload.user_id
    end
  end
end
