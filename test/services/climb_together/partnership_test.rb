# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  class PartnershipTest < ActiveSupport::TestCase
    setup do
      @inviter = users(:one)
      @invitee = users(:two)
      @other = users(:admin)
      ClimbPartnership.delete_all
      HighFive.delete_all
    end

    test "Invite reuses the same pending invite" do
      first = Invite.call(user: @inviter)
      second = Invite.call(user: @inviter)

      assert_equal first.id, second.id
      assert_equal "pending", first.status
      assert first.token.present?
      assert_nil first.invitee_id
      assert_equal 1, ClimbPartnership.where(inviter: @inviter, status: "pending").count
    end

    test "Invite is blocked when the user already has an active partner" do
      invite = Invite.call(user: @inviter)
      Accept.call(user: @invitee, token: invite.token)

      error = assert_raises(Error) { Invite.call(user: @inviter) }
      assert_match(/active partner/i, error.message)

      error = assert_raises(Error) { Invite.call(user: @invitee) }
      assert_match(/active partner/i, error.message)
    end

    test "Accept happy path sets invitee active and accepted_at" do
      invite = Invite.call(user: @inviter)

      travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
        partnership = Accept.call(user: @invitee, token: invite.token)

        assert_equal "active", partnership.status
        assert_equal @invitee.id, partnership.invitee_id
        assert_equal Time.zone.local(2026, 11, 17, 12, 0, 0), partnership.accepted_at
      end
    end

    test "Accept rejects self-accept" do
      invite = Invite.call(user: @inviter)

      error = assert_raises(Error) { Accept.call(user: @inviter, token: invite.token) }
      assert_match(/own invite/i, error.message)
      assert_equal "pending", invite.reload.status
    end

    test "Accept rejects when the invitee already has an active partner" do
      first = Invite.call(user: @inviter)
      Accept.call(user: @invitee, token: first.token)

      other_invite = Invite.call(user: @other)
      error = assert_raises(Error) { Accept.call(user: @invitee, token: other_invite.token) }
      assert_match(/active partner/i, error.message)
    end

    test "Accept rejects when the inviter already has an active partner" do
      first = Invite.call(user: @inviter)
      Accept.call(user: @invitee, token: first.token)

      leftover = ClimbPartnership.create!(inviter: @invitee, status: "pending")
      error = assert_raises(Error) { Accept.call(user: @other, token: leftover.token) }
      assert_match(/active partner/i, error.message)
    end

    test "End marks the active partnership ended" do
      invite = Invite.call(user: @inviter)
      Accept.call(user: @invitee, token: invite.token)

      travel_to Time.zone.local(2026, 11, 17, 15, 0, 0) do
        ended = End.call(user: @inviter)

        assert_equal "ended", ended.status
        assert_equal Time.zone.local(2026, 11, 17, 15, 0, 0), ended.ended_at
        assert_nil PartnerFor.call(user: @inviter)
        assert_nil PartnerFor.call(user: @invitee)
      end
    end

    test "PartnerFor returns the other user from both sides" do
      invite = Invite.call(user: @inviter)
      Accept.call(user: @invitee, token: invite.token)

      assert_equal @invitee, PartnerFor.call(user: @inviter)
      assert_equal @inviter, PartnerFor.call(user: @invitee)
      assert_nil PartnerFor.call(user: @other)
    end
  end
end
