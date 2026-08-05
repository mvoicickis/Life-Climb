# frozen_string_literal: true

# VAPID keys for Web Push. Prefer ENV in production; fall back to
# Rails credentials, then a generated pair in tmp/ for local/dev/test.
module VapidConfig
  module_function

  def public_key
    configured_public_key.presence || local_keys.fetch(:public_key)
  end

  def private_key
    configured_private_key.presence || local_keys.fetch(:private_key)
  end

  def subject
    ENV.fetch("VAPID_SUBJECT", "mailto:support@lifepoints.app")
  end

  def configured?
    public_key.present? && private_key.present?
  end

  def configured_public_key
    ENV["VAPID_PUBLIC_KEY"].presence ||
      Rails.application.credentials.dig(:vapid, :public_key).presence
  end

  def configured_private_key
    ENV["VAPID_PRIVATE_KEY"].presence ||
      Rails.application.credentials.dig(:vapid, :private_key).presence
  end

  def local_keys
    @local_keys ||= begin
      path = Rails.root.join("tmp/vapid_keys.json")
      if path.exist?
        JSON.parse(path.read).symbolize_keys
      else
        key = WebPush.generate_key
        data = { public_key: key.public_key, private_key: key.private_key }
        FileUtils.mkdir_p(path.dirname)
        path.write(JSON.pretty_generate(data))
        data
      end
    end
  end
end
