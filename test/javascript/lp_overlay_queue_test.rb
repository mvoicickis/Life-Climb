# frozen_string_literal: true

require "test_helper"

# Contract test for the overlay queue source (no Node runner in CI).
class LpOverlayQueueTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/javascript/lib/lp_overlay_queue.js").read
    @climb = Rails.root.join("app/javascript/controllers/climb_reward_controller.js").read
    @streak = Rails.root.join("app/javascript/controllers/streak_moment_controller.js").read
    @finale = Rails.root.join("app/javascript/controllers/today_finale_controller.js").read
    @push = Rails.root.join("app/javascript/controllers/push_offer_controller.js").read
    @show = Rails.root.join("app/views/dashboard/show_v2.html.erb").read
  end

  test "queue orders finale then streak then climb_reward then push_offer" do
    assert_includes @source, "finale: 10"
    assert_includes @source, "streak: 20"
    assert_includes @source, "climb_reward: 30"
    assert_includes @source, "push_offer: 40"
    assert_includes @source, "export function enqueue"
    assert_includes @source, "export function release"
  end

  test "finale streak climb and push wait on the queue" do
    assert_includes @finale, 'enqueue("finale"'
    assert_includes @finale, 'release("finale")'
    assert_includes @climb, 'enqueue("climb_reward"'
    assert_includes @climb, 'release("climb_reward")'
    assert_includes @streak, 'enqueue("streak"'
    assert_includes @streak, 'release("streak")'
    assert_includes @push, 'enqueue("push_offer"'
    assert_includes @push, 'release("push_offer")'
  end

  test "today hosts finale next to streak under today-dash-root" do
    assert_includes @show, 'id="today-finale-host"'
    assert_includes @show, 'id="streak-moment-host"'
    finale_at = @show.index('id="today-finale-host"')
    streak_at = @show.index('id="streak-moment-host"')
    root_end = @show.index("</div>\n\n<% if flash[:lp_toast]")
    assert finale_at < streak_at
    assert streak_at < root_end
  end
end
