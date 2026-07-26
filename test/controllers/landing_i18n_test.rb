require "test_helper"

class LandingI18nTest < ActionDispatch::IntegrationTest
  test "landing page is available in english by default" do
    get root_path
    assert_response :success
    assert_match(/One mountain\. Today’s battle/, response.body)
    assert_match(/Start free/, response.body)
    assert_match(/Action Points/, response.body)
    assert_match(/Finish projects to climb/, response.body)
    assert_no_match(/you move closer to the top/i, response.body)
  end

  test "landing page switches to latvian with product-true copy" do
    patch locale_path(locale: :lv)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Viens kalns\. Šodienas kauja/, response.body)
    assert_match(/Sākt bez maksas/, response.body)
    assert_match(/Action Points/, response.body)
    assert_match(/Pabeidz projektus, lai kāptu/i, response.body)
    assert_no_match(/tuvojies virsotnei/i, response.body)
    assert_select ".lp-landing-chip", text: /Es/
    assert_select ".lp-landing-chip", text: /Karjera/
    assert_select ".lp-landing-chip", text: /Nauda/
    assert_select ".lp-landing-chip", text: /Attiecības/
    assert_select ".lp-landing-chip", text: /Jēga/
    assert_select ".lp-landing-chip--more", text: /\+ 8 vēl/
    assert_select ".lp-landing-chip", text: /\A\s*Self\s*\z/, count: 0
  end

  test "landing page switches to german with product-true copy" do
    patch locale_path(locale: :de)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Ein Berg\. Die Schlacht von heute/, response.body)
    assert_match(/Kostenlos starten/, response.body)
    assert_match(/Action Points/, response.body)
    assert_match(/Beende Projekte, um deinen Berg/i, response.body)
    assert_no_match(/kommst dem Gipfel näher/i, response.body)
    assert_select ".lp-landing-chip", text: /Selbst/
    assert_select ".lp-landing-chip", text: /Karriere/
    assert_select ".lp-landing-chip", text: /Geld/
    assert_select ".lp-landing-chip", text: /Beziehungen/
    assert_select ".lp-landing-chip", text: /Sinn/
    assert_select ".lp-landing-chip--more", text: /\+ 8 weitere/
    assert_select ".lp-landing-chip", text: /\A\s*Self\s*\z/, count: 0
  end

  test "landing page switches to spanish with product-true copy" do
    patch locale_path(locale: :es)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Una montaña\. La batalla de hoy/, response.body)
    assert_match(/Empezar gratis/, response.body)
    assert_match(/Action Points/, response.body)
    assert_match(/Termina proyectos para subir/i, response.body)
    assert_no_match(/te acercas a la cima/i, response.body)
    assert_select ".lp-landing-chip", text: /Yo/
    assert_select ".lp-landing-chip", text: /Carrera/
    assert_select ".lp-landing-chip", text: /Dinero/
    assert_select ".lp-landing-chip", text: /Relaciones/
    assert_select ".lp-landing-chip", text: /Propósito/
    assert_select ".lp-landing-chip--more", text: /\+ 8 más/
    assert_select ".lp-landing-chip", text: /\A\s*Self\s*\z/, count: 0
  end

  test "signed-in german nav uses Today Strategy Journey You labels" do
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
    patch locale_path(locale: :de)
    follow_redirect!
    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-nav__link", text: /Heute/i
    assert_select ".lp-dash-nav__link", text: /Strategie/i
    assert_select ".lp-dash-nav__link", text: /Reise/i
    assert_select ".lp-dash-nav__link", text: /Du/i

    get life_points_path
    assert_response :success
    assert_match(/Reise/, response.body)
    assert_match(/Berg-Zusammenfassung/, response.body)
    assert_match(/Action Points/, response.body)
  end
end
