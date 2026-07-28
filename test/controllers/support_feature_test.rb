require "test_helper"

class SupportFeatureTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "support page is calm and shows coffee option" do
    sign_in_as @user
    get support_path
    assert_response :success
    assert_match(/Support LifePoints/, response.body)
    assert_match(/Buy the developer a coffee/, response.body)
    assert_match(%r{href="https://buymeacoffee\.com/lifepoints"}, response.body)
    assert_match(/Become a Supporter/, response.body)
    assert_match(/Sponsor Development/, response.body)
    assert_match(/Make a Contribution/, response.body)
    refute_match(/More ways to support — soon/, response.body)
  end

  test "support page includes invite share sheet" do
    sign_in_as @user
    get support_path
    assert_response :success
    assert_match(/Share LifePoints/, response.body)
    assert_match(/Invite a friend/, response.body)
    assert_match(/data-controller="share"/, response.body)
    assert_match(/data-action="click-&gt;share#open"|data-action="click->share#open"/, response.body)
    assert_match(/share-sheet/, response.body)
    assert_match(%r{/\?s=lp}, response.body)
  end

  test "about page links to support" do
    sign_in_as @user
    get about_path
    assert_response :success
    assert_match(/About/, response.body)
    assert_select "a[href=?]", support_path
  end

  test "settings links to support and offers invite share" do
    sign_in_as @user
    get settings_path
    assert_response :success
    assert_select "a[href=?]", support_path
    assert_match(/Share LifePoints/, response.body)
    assert_match(/data-controller="share"/, response.body)
    assert_match(/share-sheet/, response.body)
  end

  test "first finished product offers thank-you once" do
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Code",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [])
    product = @user.finished_products.create!(
      title: "Portfolio site",
      shipped_on: Date.current,
      value_summary: "People can hire me"
    )

    get finished_product_path(product)
    assert_response :success
    assert_match(/first Finished Product|honored/i, response.body)

    get finished_product_path(product)
    assert_response :success
    refute_match(/Don’t ask again|Don't ask again/, response.body)
  end

  test "mute permanently stops moments" do
    sign_in_as @user
    @user.finished_products.create!(title: "App", shipped_on: Date.current)
    post dismiss_support_moment_path, params: { mute: 1 }
    assert @user.reload.support_prompts_muted?

    get life_points_path
    refute_match(/We’re honored|We're honored|Congratulations/, response.body)
  end
end

class SupportMomentTest < ActiveSupport::TestCase
  test "creation weights stay higher than coffee guilt" do
    user = users(:one)
    moment = SupportMoment.new(user)
    assert_nil moment.eligible

    user.finished_products.create!(title: "Book", shipped_on: Date.current)
    assert_equal :first_finished_product, moment.eligible
  end
end

class SupportProvidersTest < ActiveSupport::TestCase
  test "primary coffee provider opens buymeacoffee lifepoints page" do
    primary = SupportProviders.primary
    assert primary
    assert_equal :buy_me_a_coffee, primary[:id]
    assert_equal "https://buymeacoffee.com/lifepoints", primary[:url]
  end

  test "all support options open the same buymeacoffee page" do
    urls = SupportProviders.enabled.map { |p| p[:url] }.uniq
    assert_equal [ "https://buymeacoffee.com/lifepoints" ], urls
    assert_empty SupportProviders.coming_soon
  end
end
