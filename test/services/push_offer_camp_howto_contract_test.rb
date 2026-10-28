# frozen_string_literal: true

require "test_helper"

# Source contract for camp-sheet how-to when push cannot work (no JS unit runner).
class PushOfferCampHowtoContractTest < ActiveSupport::TestCase
  setup do
    @push = Rails.root.join("app/javascript/push_subscription.js").read
    @offer = Rails.root.join("app/javascript/controllers/push_offer_controller.js").read
    @finish = Rails.root.join("app/views/life_journeys/_trail_camp_finish_card.html.erb").read
  end

  test "isInAppBrowser matches ApplicationHelper social WebView tokens" do
    assert_match(/export function isInAppBrowser/, @push)
    %w[FBAN FBAV FB_IAB FBIOS Instagram Messenger].each do |token|
      assert_includes @push, token
    end
  end

  test "camp prepareOffer prefers in-app then ios how-to and skips other unsupported" do
    assert_includes @offer, "isInAppBrowser"
    assert_includes @offer, "campSheetMode"
    assert_includes @offer, 'this.renderCampHowToCard("inapp")'
    assert_includes @offer, 'this.renderCampHowToCard("ios")'
    assert_includes @offer, 'console.info("[PushOffer] skip", "unsupported")'
    assert_includes @offer, 'console.info("[PushOffer] skip", "no_vapid")'
    refute_includes @offer, 'console.info("[PushOffer] skip", "ios")'
  end

  test "camp how-to has no yes button and does not open push-offer CTA whitening" do
    assert_includes @offer, "renderCampHowToCard"
    assert_includes @offer, "is-camp-howto"
    assert_includes @offer, "this.yesButton = null"
    start = @offer.index("renderCampHowToCard(kind)")
    finish = @offer.index("\n  markShownIfNeeded", start)
    howto = @offer[start...finish]
    assert howto.present?
    refute_includes howto, "setPushOfferOpen(true)"
    refute_includes howto, "lp-push-offer__yes"
    assert_includes howto, "markShownIfNeeded()"
  end

  test "mountain push offer host sits under the finish card not inside it" do
    assert_match(/first_win && camp_push_offer/, @finish)
    assert_includes @finish, 'host_id: "mountain-push-offer-host"'
    # Host render follows the prompt card close, not nested inside title/CTA markup.
    host_idx = @finish.index("mountain-push-offer-host")
    cta_idx = @finish.index("lp-trail-camp-finish__cta")
    assert host_idx
    assert cta_idx
    assert_operator host_idx, :>, cta_idx
  end
end

