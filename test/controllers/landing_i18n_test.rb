require "test_helper"

class LandingI18nTest < ActionDispatch::IntegrationTest
  test "landing page is available in english by default" do
    get root_path
    assert_response :success
    assert_match(/Most goals die in your notes app/, response.body)
    assert_match(/Start free/, response.body)
    assert_match(/Battle strength/, response.body)
    assert_match(/Name today's battle/, response.body)
    assert_match(/Run my first 10 km/, response.body)
    assert_match(/Win the battle\. Your mountain rises/, response.body)
    assert_no_match(/Early climbers are already on their way/, response.body)
    assert_no_match(/you move closer to the top/i, response.body)
    assert_no_match(/Run my first 10K[^m]/, response.body)
  end

  test "landing page switches to latvian with product-true copy" do
    patch locale_path(locale: :lv)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Lielākā daļa mērķu nomirst piezīmju lietotnē/, response.body)
    assert_match(/Sākt bez maksas/, response.body)
    assert_match(/Battle strength/, response.body)
    assert_match(/Name today's battle/, response.body)
    assert_match(/10 km/, response.body)
    assert_no_match(/Pirmie kāpēji jau ir ceļā/, response.body)
    assert_no_match(/tuvojies virsotnei/i, response.body)
    assert_select ".lp-landing-chip", text: /Es/
    assert_select ".lp-landing-chip", text: /Karjera/
    assert_select ".lp-landing-chip", text: /Nauda/
    assert_select ".lp-landing-chip", text: /Attiecības/
    assert_select ".lp-landing-chip", text: /Jēga/
    assert_select ".lp-landing-chip--more", text: /kad būsi gatavs/
    assert_select ".lp-landing-chip", text: /\A\s*Self\s*\z/, count: 0
  end

  test "landing page switches to german with product-true copy" do
    patch locale_path(locale: :de)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Die meisten Ziele sterben in der Notizen-App/, response.body)
    assert_match(/Kostenlos starten/, response.body)
    assert_match(/Battle strength/, response.body)
    assert_match(/Name today's battle/, response.body)
    assert_match(/10 km/, response.body)
    assert_no_match(/Frühe Kletterer sind schon unterwegs/, response.body)
    assert_no_match(/kommst dem Gipfel näher/i, response.body)
    assert_select ".lp-landing-chip", text: /Selbst/
    assert_select ".lp-landing-chip", text: /Karriere/
    assert_select ".lp-landing-chip", text: /Geld/
    assert_select ".lp-landing-chip", text: /Beziehungen/
    assert_select ".lp-landing-chip", text: /Sinn/
    assert_select ".lp-landing-chip--more", text: /wenn du bereit bist/
    assert_select ".lp-landing-chip", text: /\A\s*Self\s*\z/, count: 0
  end

  test "landing page switches to spanish with product-true copy" do
    patch locale_path(locale: :es)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/La mayoría de las metas mueren en tu app de notas/, response.body)
    assert_match(/Empezar gratis/, response.body)
    assert_match(/Battle strength/, response.body)
    assert_match(/Name today's battle/, response.body)
    assert_match(/10 km/, response.body)
    assert_no_match(/Los primeros escaladores ya van de camino/, response.body)
    assert_no_match(/te acercas a la cima/i, response.body)
    assert_select ".lp-landing-chip", text: /Yo/
    assert_select ".lp-landing-chip", text: /Carrera/
    assert_select ".lp-landing-chip", text: /Dinero/
    assert_select ".lp-landing-chip", text: /Relaciones/
    assert_select ".lp-landing-chip", text: /Propósito/
    assert_select ".lp-landing-chip--more", text: /cuando estés listo/
    assert_select ".lp-landing-chip", text: /\A\s*Self\s*\z/, count: 0
  end

  test "signed-in german nav uses Mountain Today Stats You labels" do
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
    # Journey page is hierarchy-gate exempt and always shows primary nav.
    get life_points_path
    assert_response :success
    assert_select ".lp-dash-nav__link", text: /Heute/i
    assert_select ".lp-dash-nav__link", text: /Berg/i
    assert_select ".lp-dash-nav__link", text: /Du/i
    assert_select ".lp-dash-nav__link", text: /Gewohnheiten/i, count: 0
    assert_select ".lp-dash-nav__link", text: /Statistik/i
    assert_match(/Statistik/, response.body)
    assert_select ".stats-hero"
    assert_match(/Aktionspunkte/, response.body)
  end
end
