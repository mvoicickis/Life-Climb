# frozen_string_literal: true

require "test_helper"

class TesterContactTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "whatsapp_url strips spaces plus and leading 00" do
    contact = TesterContact.new(user: @user, channel: "whatsapp", details: "+00 353 87 234 6580")

    assert_equal "353872346580", contact.whatsapp_digits
    assert_equal "https://wa.me/353872346580", contact.whatsapp_url
  end

  test "whatsapp_url is nil when fewer than 8 digits" do
    contact = TesterContact.new(user: @user, channel: "whatsapp", details: "123 456")

    assert_equal "123456", contact.whatsapp_digits
    assert_nil contact.whatsapp_url
  end

  test "whatsapp_url is nil without digits" do
    contact = TesterContact.new(user: @user, channel: "whatsapp", details: "Luis on WhatsApp")

    assert_nil contact.whatsapp_digits
    assert_nil contact.whatsapp_url
  end

  test "mailto uses details when present" do
    contact = TesterContact.new(user: @user, channel: "email", details: "reach@example.com")

    assert_equal "mailto:reach@example.com", contact.mailto_url(fallback_email: @user.email_address)
  end

  test "mailto falls back to account email when details blank" do
    contact = TesterContact.new(user: @user, channel: "email", details: "")

    assert_equal "mailto:#{@user.email_address}", contact.mailto_url(fallback_email: @user.email_address)
  end

  test "contacted_recently covers last three days" do
    travel_to Date.new(2026, 11, 18) do
      recent = TesterContact.new(user: @user, last_contacted_on: Date.new(2026, 11, 15))
      stale = TesterContact.new(user: @user, last_contacted_on: Date.new(2026, 11, 14))

      assert recent.contacted_recently?
      assert_not stale.contacted_recently?
      assert_not TesterContact.new(user: @user).contacted_recently?
    end
  end
end
