require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "landing page is public" do
    get root_path
    assert_response :success
    assert_match(/One mountain\. Today’s battle/, response.body)
    assert_match(/Start free/, response.body)
    assert_match(/How it works/, response.body)
    assert_match(/Your life, one area at a time/, response.body)
    assert_match(/Every point makes you more alive/, response.body)
    assert_match(/Run my first 10K/, response.body)
    assert_no_match(/status\.better_full|landing\.sample_better|today-card--good|lifepoints-landing-hero\.jpg/, response.body)
  end

  test "landing page uses mountain brand mark" do
    get root_path
    assert_response :success
    assert_match(%r{/branding/lifepoints-mark\.png}, response.body)
    assert_no_match(%r{/branding/lifepoints-leaf-mark\.png}, response.body)
  end

  test "landing social meta uses mountain logo og image" do
    get root_path
    assert_response :success
    assert_match(/name="theme-color" content="#FFFFFF"/, response.body)
    assert_match(%r{og:image" content="https://[^"]+/og-lifepoints-logo\.png"}, response.body)
    assert_match(/og:image:alt" content="LifePoints — One mountain\. Today’s battle\."/, response.body)
  end

  test "signed in users go to dashboard from root" do
    sign_in_as users(:one)
    get root_path
    assert_redirected_to dashboard_path
  end
end
