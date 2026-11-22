# frozen_string_literal: true

require "test_helper"

class TodayBattleDeepLinkContractTest < ActiveSupport::TestCase
  setup do
    @js = Rails.root.join("app/javascript/controllers/today_battle_deep_link_controller.js").read
    @show = Rails.root.join("app/views/dashboard/show_v2.html.erb").read
    @row = Rails.root.join("app/views/dashboard/_dash_battlefield_row.html.erb").read
    @css = Rails.root.join("app/assets/stylesheets/today_v2.css").read
  end

  test "today root wires deep link controller" do
    assert_includes @show, "today-battle-deep-link"
  end

  test "battle rows expose todo id for deep link matching" do
    assert_includes @row, 'data-todo-id="<%= todo.id %>"'
  end

  test "deep link controller strips battle param and highlights row" do
    assert_includes @js, 'params.get("battle")'
    assert_includes @js, "history.replaceState"
    assert_includes @js, "is-push-highlight"
    assert_includes @js, "is-won-row"
    assert_includes @js, "prefers-reduced-motion"
  end

  test "push highlight uses design tokens" do
    assert_includes @css, ".lp-today-v2-row.is-push-highlight"
    assert_includes @css, "var(--lp-green)"
  end
end
