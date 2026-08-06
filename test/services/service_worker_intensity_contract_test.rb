# frozen_string_literal: true

require "test_helper"

class ServiceWorkerIntensityContractTest < ActiveSupport::TestCase
  setup do
    @source = Rails.root.join("app/views/pwa/service-worker.js").read
  end

  test "gentle maps silent requireInteraction false and empty vibrate" do
    assert_includes @source, 'case "gentle":'
    assert_match(/silent:\s*true/, @source)
    assert_match(/requireInteraction:\s*false/, @source)
    assert_match(/vibrate:\s*\[\s*\]/, @source)
  end

  test "persistent maps requireInteraction vibrate pattern and silent false" do
    assert_includes @source, 'case "persistent":'
    assert_match(/requireInteraction:\s*true/, @source)
    assert_match(/vibrate:\s*\[\s*200,\s*100,\s*200\s*\]/, @source)
    assert_match(/silent:\s*false/, @source)
  end

  test "normal path omits intensity options via empty default return" do
    assert_includes @source, "default:"
    assert_match(/return \{\s*\}/, @source)
    assert_includes @source, "...intensityOptions(data.intensity)"
  end

  test "cache version bumped for intensity options" do
    assert_match(/CACHE_VERSION = "v[6-9]"/, @source)
  end
end
