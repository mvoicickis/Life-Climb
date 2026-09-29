# frozen_string_literal: true

require "test_helper"

class FixedViewportTodayTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
  end

  test "photo today renders battlefield shell and nav" do
    get dashboard_path
    assert_response :success

    assert_select "#today-dash-root.lp-dash.is-today-v2.is-today-photo", count: 1
    assert_select ".lp-today-scroll__pad", count: 1
    assert_select "#today-dash-nav .lp-dash-nav.is-v4", count: 1
  end

  test "stylesheet locks photo today to 100dvh and scrolls inside scroll pad" do
    css = Rails.root.join("app/assets/stylesheets/today_v2.css").read

    shell = css[/html:has\(\.lp-dash\.is-today-v2\.is-today-photo\),\s*\nhtml:has\(\.lp-dash\.is-today-v2\.is-today-photo\) body,\s*\n\.lp-game:has\(\.lp-dash\.is-today-v2\.is-today-photo\)\s*\{[^}]+\}/m]
    assert shell.present?, "expected photo Today shell lock block in today_v2.css"
    assert_match(/max-height:\s*100dvh/, shell)
    assert_match(/overflow:\s*hidden/, shell)
    assert_match(/overscroll-behavior:\s*none/, shell)

    game_blocks = css.scan(/\.lp-game:has\(\.lp-dash\.is-today-v2\.is-today-photo\)\s*\{[^}]+\}/m)
    assert_operator game_blocks.size, :>=, 2, "expected shared + dedicated .lp-game photo Today rules"
    dedicated_game = game_blocks.find { |block| block.match?(/padding-bottom:\s*0/) }
    assert dedicated_game.present?, "expected dedicated .lp-game block with padding-bottom: 0"
    assert_match(/height:\s*100dvh/, dedicated_game)

    main = css[/\.lp-main:has\(\.lp-dash\.is-today-v2\.is-today-photo\)\s*\{[^}]+\}/m]
    assert main.present?
    assert_match(/overflow:\s*hidden/, main)
    assert_match(/padding:\s*0/, main)

    pad = css[/\.lp-dash\.is-today-v2\.is-today-photo \.lp-today-scroll__pad\s*\{[^}]+\}/m]
    assert pad.present?
    assert_match(/overflow-y:\s*auto/, pad)
    assert_match(/overscroll-behavior-y:\s*contain/, pad)
    assert_match(
      /padding:\s*0 var\(--lp-gutter\) calc\(5\.5rem \+ env\(safe-area-inset-bottom\)\)/,
      pad
    )
  end
end
