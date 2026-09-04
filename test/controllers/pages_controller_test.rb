require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "landing page is public" do
    assert_difference -> { UserEvent.named("landing_viewed").count }, 1 do
      get root_path
    end
    assert_response :success
    assert_select "h1.lp-landing-hero__title", text: "The mountain is yours to climb"
    assert_select ".lp-landing-nav__tagline", count: 0
    assert_match(/Start free/, response.body)
    assert_match(/How it works/, response.body)
    assert_match(/Your life, one area at a time/, response.body)
    assert_match(/Proof you did something real/, response.body)
    assert_match(/Run my first 10 km/, response.body)
    assert_match(/Name today(?:&#39;|')s battle/i, response.body)
    assert_match(/Battle strength/, response.body)
    assert_match(/Win the battle\. Your mountain rises/, response.body)
    assert_match(/Free to start/, response.body)
    assert_match(/\+50/, response.body)
    assert_match(/Battle strength/, response.body)
    assert_no_match(/\+50 LP/, response.body)
    assert_no_match(/\+50 AP/, response.body)
    assert_no_match(/Early climbers are already on their way/, response.body)
    assert_no_match(/Your progress, made simple/, response.body)
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

  test "landing social meta uses Life Climb og image and tagline" do
    get root_path
    assert_response :success
    assert_match(/name="theme-color" content="#f8fafc"/, response.body)
    assert_match(%r{og:image" content="https://lifeclimb\.app/og-lifeclimb-share\.png"}, response.body)
    assert_match(/og:description" content="The mountain is yours to climb"/, response.body)
    assert_match(/og:title" content="Life Climb — The mountain is yours to climb"/, response.body)
    assert_match(/twitter:title" content="Life Climb — The mountain is yours to climb"/, response.body)
    assert_match(/og:image:alt" content="Life Climb — The mountain is yours to climb"/, response.body)
    assert_match(%r{og:url" content="https://lifeclimb\.app/"}, response.body)
    assert_match(%r{rel="canonical" href="https://lifeclimb\.app/"}, response.body)
    assert_match(/application\/ld\+json/, response.body)
    assert_match(/SoftwareApplication/, response.body)
  end

  test "robots and sitemap are public" do
    get "/robots.txt"
    assert_response :success
    assert_match(/User-agent:\s*\*/i, response.body)
    assert_match(%r{Sitemap:\s*https://lifeclimb\.app/sitemap\.xml}, response.body)

    get "/sitemap.xml"
    assert_response :success
    assert_match(%r{https://lifeclimb\.app/}, response.body)
    assert_match(%r{https://lifeclimb\.app/about}, response.body)
    assert_match(%r{https://lifeclimb\.app/registration/new}, response.body)
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

    assert_no_difference -> { UserEvent.named("landing_viewed").count } do
      get root_path
    end
    assert_redirected_to dashboard_path
  end
end
