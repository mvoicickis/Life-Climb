require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "landing page is public" do
    get root_path
    assert_response :success
    assert_match(/Most goals die in your notes app/, response.body)
    assert_match(/Start free/, response.body)
    assert_match(/How it works/, response.body)
    assert_match(/Your life, one area at a time/, response.body)
    assert_match(/Every point makes you more alive/, response.body)
    assert_match(/Run my first 10 km/, response.body)
    assert_match(/Name today’s step/i, response.body)
    assert_match(/Action Points/i, response.body)
    assert_match(/Watch your mountain rise/i, response.body)
    assert_match(/Early climbers are already on their way/, response.body)
    assert_match(/Free to start/, response.body)
    assert_match(/\+50 AP/, response.body)
    assert_match(/Action Points/, response.body)
    assert_no_match(/\+50 LP/, response.body)
    assert_no_match(/you move closer to the top/i, response.body)
    assert_no_match(/status\.better_full|landing\.sample_better|today-card--good|lifepoints-landing-hero\.jpg/, response.body)
  end

  test "auth pages use mountain brand mark" do
    get new_session_path
    assert_response :success
    assert_match(%r{/branding/lifepoints-mark\.png}, response.body)
    assert_no_match(/auth-topbar-mark">🌿/, response.body)

    get new_registration_path
    assert_response :success
    assert_match(%r{/branding/lifepoints-mark\.png}, response.body)
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
    assert_match(/name="theme-color" content="#f8fafc"/, response.body)
    assert_match(%r{og:image" content="https://[^"]+/og-lifepoints-brand\.png"}, response.body)
    assert_match(/og:image:alt" content="LifePoints — Most goals die in your notes app\."/, response.body)
    assert_match(%r{og:url" content="https://[^"]+/"}, response.body)
    assert_match(/application\/ld\+json/, response.body)
    assert_match(/SoftwareApplication/, response.body)
    assert_match(/Action Points/, response.body)
  end

  test "robots and sitemap are public" do
    get "/robots.txt"
    assert_response :success
    assert_match(/User-agent:\s*\*/i, response.body)
    assert_match(%r{Sitemap:\s*https://lifepoints\.onrender\.com/sitemap\.xml}, response.body)

    get "/sitemap.xml"
    assert_response :success
    assert_match(%r{https://lifepoints\.onrender\.com/}, response.body)
    assert_match(%r{https://lifepoints\.onrender\.com/about}, response.body)
    assert_match(%r{https://lifepoints\.onrender\.com/registration/new}, response.body)
  end

  test "signed in users go to dashboard from root" do
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])

    get root_path
    assert_redirected_to dashboard_path
  end
end
