# frozen_string_literal: true

require "test_helper"

class ReferralShareSignupTest < ActionDispatch::IntegrationTest
  setup do
    @referrer = users(:one)
    @share_url = ReferralShareUrl.for(@referrer)
  end

  test "visit share URL then email signup attributes referrer" do
    query = Rack::Utils.parse_query(URI.parse(@share_url).query)
    get root_path, params: query
    assert_response :success

    email = "share-ref-#{SecureRandom.hex(4)}@example.com"
    assert_difference("User.count", 1) do
      post registration_url, params: {
        user: {
          name: "From share",
          email_address: email,
          password: "password12345"
        }
      }
    end

    user = User.find_by!(email_address: email)
    assert_equal @referrer.id, user.referred_by_id
  end
end
