# frozen_string_literal: true

require "test_helper"

# Source contracts for Today moments (no Node runner in CI).
class TodayMomentsContractTest < ActiveSupport::TestCase
  setup do
    @queue = Rails.root.join("app/javascript/lib/lp_overlay_queue.js").read
    @finale_js = Rails.root.join("app/javascript/controllers/today_finale_controller.js").read
    @streak_js = Rails.root.join("app/javascript/controllers/streak_moment_controller.js").read
    @sound = Rails.root.join("app/javascript/lib/lp_sound.js").read
    @layout = Rails.root.join("app/views/layouts/application.html.erb").read
    @show = Rails.root.join("app/views/dashboard/show_v2.html.erb").read
    @header = Rails.root.join("app/views/dashboard/_dash_battlefield_header.html.erb").read
    @body = Rails.root.join("app/views/dashboard/_dash_battlefield_body.html.erb").read
    @streak_erb = Rails.root.join("app/views/dashboard/_streak_moment.html.erb").read
    @schema = Rails.root.join("db/schema.rb").read
  end

  test "overlay queue shows one overlay at a time and in order" do
    assert_includes @queue, "finale: 10"
    assert_includes @queue, "streak: 20"
    assert_includes @queue, "climb_reward: 30"
    assert_includes @queue, "push_offer: 40"
    assert_includes @finale_js, 'enqueue("finale"'
    assert_includes @streak_js, 'enqueue("streak"'
    assert_includes @show, 'id="today-finale-host"'
    assert_includes @show, 'id="streak-moment-host"'
  end

  test "finale streams only on all_clear once per day and plays all_won" do
    stream = Rails.root.join("app/views/daily_todos/complete.turbo_stream.erb").read
    service = Rails.root.join("app/services/today/finale_moment.rb").read
    assert_includes stream, 'turbo_stream.update "today-finale-host"'
    assert_includes service, "all_clear?"
    assert_includes service, "last_finale_on"
    assert_includes @finale_js, 'sound("all_won")'
    assert_includes @finale_js, "haptic([ 20, 40, 20 ])"
  end

  test "streak record line only when data-record true and week strip has run pill" do
    assert_includes @streak_erb, 'data-record="<%= moment.new_record ? \'true\' : \'false\' %>"'
    assert_includes @streak_erb, "lp-streak-moment__pill"
    assert_includes @streak_erb, "lp-streak-moment__future"
    assert_includes @streak_erb, "lp-streak-moment__past"
    assert_includes @streak_erb, "climb.streak_moment.show_it_off"
    assert_includes @streak_erb, "grid-column:"
    assert_includes @streak_erb, "strip_run_start"
    assert_includes @streak_erb, "hero_animal_image_path"
    assert_includes @streak_erb, "moment.from_days"
    refute_includes @streak_erb, "is-missed"
    refute_includes @streak_erb, "day-mark"
    refute_includes @streak_erb, "fireball"
    refute_includes @streak_erb, "lp-streak-moment__flood"
    refute_includes @streak_erb, "lp-streak-moment__runner"
    refute_includes @streak_erb, "streak_fire.json"
    css = Rails.root.join("app/assets/stylesheets/streak_moment.css").read
    assert_includes css, '.lp-streak-moment[data-record="true"] .lp-streak-moment__record'
  end

  test "streak moment uses brand white tokens without fire palette" do
    css = Rails.root.join("app/assets/stylesheets/streak_moment.css").read
    refute_includes css, "--lp-fire"
    refute_includes css, "lp-streak-moment__fireball"
    refute_includes css, "lp-streak-moment__flood"
    refute_includes css, "lp-streak-moment__runner"
    assert_includes css, "background: var(--lp-surface)"
    assert_includes css, "color: var(--lp-ink)"
    assert_includes css, "background: var(--lp-green)"
    assert_includes css, "color: var(--lp-green-deep)"
    assert_includes css, "lp-streak-moment__confetti"
    assert_includes @streak_js, "is-flipping"
    assert_includes @streak_js, "is-week"
    assert_includes @streak_js, "is-running"
    assert_includes @streak_js, "is-cta"
    assert_includes @streak_js, "is-final"
    assert_includes @streak_js, "burstGreenConfetti"
    assert_includes @streak_js, "revealChecks"
    refute_includes @streak_js, "is-flying"
    refute_includes @streak_js, "is-impact"
    refute_includes @streak_js, "lottie-web"
    refute_includes @streak_js, "lottieUrl"
  end

  test "empty ready state and plus-one goal bar target exist" do
    assert_includes @body, "lp-today-ready"
    assert_includes @body, "ready_title"
    assert_includes @header, "data-today-goal-bar"
  end

  test "sound fallbacks without files and reduced motion short-circuit" do
    assert_includes @layout, "lp-sound-urls"
    assert_includes @layout, 'app/assets/sounds/#{name}.mp3'
    %w[win all_won streak_whoosh streak_tick cheer tap].each do |name|
      assert_match(/name === "#{name}"|name === "streak"/, @sound)
    end
    assert_includes @sound, "function playWinDing"
    assert_includes @sound, "function playAllWonSynth"
    assert_includes @sound, "function playStreakWhooshSynth"
    assert_includes @sound, "function playTapSynth"
    assert_match(/if \(!soundEnabled\(\) \|\| prefersReducedMotion\(\)\) return/, @sound)
    assert_includes @finale_js, "prefersReducedMotion()"
    assert_includes @streak_js, "prefersReducedMotion()"
    assert_includes @streak_js, "showFinal()"
  end

  test "schema has longest_streak_days and last_finale_on" do
    assert_includes @schema, 't.integer "longest_streak_days", default: 0, null: false'
    assert_includes @schema, 't.date "last_finale_on"'
  end

end
