# frozen_string_literal: true

# Content Security Policy — tighten as needed when adding third-party widgets.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self, :https
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self, "https://wa.me", "mailto:"
  end

  config.content_security_policy_nonce_generator = ->(request) {
    request.session.id.to_s.presence || SecureRandom.base64(16)
  }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Enforce (not report-only) once importmap/Turbo work with nonces.
  # Inline styles from Tailwind/utilities still need style-src unsafe_inline for now.
end
