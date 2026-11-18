# frozen_string_literal: true

require "test_helper"

module ClimbTogether
  class YouInviteRowTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @partner = users(:two)
      ClimbPartnership.delete_all
      HighFive.delete_all
      seed_climb!(@user)
      seed_climb!(@partner, area_key: "self", today_mission: "Partner battle")
      sign_in_as @user
    end

    test "You row opens climb together sheet and share url contains token" do
      get settings_path

      assert_response :success
      assert_select "#you-climb-together #you-row-climb-together.lp-you-partner", text: /Climb with someone/
      assert_select "#you-row-climb-together .lp-you-row__icon", text: "🤝"
      assert_select "#you-row-climb-together .lp-you-partner__label", text: /Climb with someone/
      assert_select "[data-controller='climb-together-invite share']"
      assert_select "#climb-together-sheet-title", text: "Climb together"

      invite = ClimbPartnership.pending_invite_by(@user)
      assert invite.present?
      assert_select "[data-share-url-value=?]", absolute_share_url(invite.token)
      assert_select "[data-share-text-value=?]", I18n.t("climb_together.share.text")
    end

    test "You row shows partner name when already climbing together" do
      invite = Invite.call(user: @user)
      Accept.call(user: @partner, token: invite.token)

      get settings_path

      assert_response :success
      assert_select "#you-climb-together a#you-row-climb-together.lp-you-partner[href=?]", climb_together_path
      assert_select "#you-row-climb-together", text: /Climbing with #{Regexp.escape(@partner.display_name)}/
      assert_select "#you-row-climb-together .lp-avatar-circle.is-sm"
      assert_select "#you-row-climb-together .lp-you-partner__label", text: /Climbing with/
      assert_select "#you-row-climb-together .lp-you-row__chev", text: "›"
      assert_select "[data-controller='climb-together-invite share']", count: 0
    end

    test "long partner name truncates on one line" do
      @partner.update!(name: "Alexandria Maximiliane With A Very Long Climbing Name")
      invite = Invite.call(user: @user)
      Accept.call(user: @partner, token: invite.token)

      get settings_path

      assert_response :success
      assert_select "#you-row-climb-together .lp-you-partner__label",
                    text: /Climbing with Alexandria Maximiliane With A Very Long Climbing Name/
      assert_match(/lp-you-partner__label/, response.body)
    end

    private

    def absolute_share_url(token)
      "#{CanonicalHost.base_url}#{climb_invite_path(token)}"
    end
  end
end
