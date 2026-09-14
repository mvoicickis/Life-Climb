# frozen_string_literal: true

# TOTP + backup codes for privileged accounts (admin / developer).
# Secrets are stored encrypted via MessageEncryptor (secret_key_base).
module UserOtp
  extend ActiveSupport::Concern

  OTP_ISSUER = "LifePoints"
  BACKUP_CODE_COUNT = 10
  # ROTP 6.x treats drift_behind / drift_ahead as seconds (not interval counts).
  # 30s ≈ one TOTP window of skew tolerance on each side of "now".
  OTP_DRIFT = 30

  class_methods do
    def otp_encryptor
      key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
                                      .generate_key("lifepoints-otp-secret", 32)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end

  def privileged_for_2fa?
    admin? || DeveloperAccess.allowed?(self)
  end

  def otp_enabled?
    otp_enabled_at.present? && otp_secret_plain.present?
  end

  def otp_secret_plain
    ciphertext = self[:otp_secret]
    return nil if ciphertext.blank?

    self.class.otp_encryptor.decrypt_and_verify(ciphertext)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def otp_secret_plain=(value)
    self[:otp_secret] =
      if value.present?
        self.class.otp_encryptor.encrypt_and_sign(value.to_s)
      end
  end

  def totp
    secret = otp_secret_plain
    return nil if secret.blank?

    ROTP::TOTP.new(secret, issuer: OTP_ISSUER)
  end

  def otp_provisioning_uri
    totp&.provisioning_uri(email_address.to_s)
  end

  def otp_qr_svg
    uri = otp_provisioning_uri
    return nil if uri.blank?

    RQRCode::QRCode.new(uri).as_svg(
      color: "0f172a",
      shape_rendering: "crispEdges",
      module_size: 3,
      standalone: true,
      use_path: true
    ).html_safe
  end

  def begin_otp_setup!
    raise I18n.t("two_factor.not_available") unless privileged_for_2fa?

    self.otp_secret_plain = ROTP::Base32.random
    self.otp_enabled_at = nil
    self.otp_backup_codes_digest = []
    save!
  end

  def confirm_otp_setup!(code)
    raise I18n.t("two_factor.not_available") unless privileged_for_2fa?
    raise I18n.t("two_factor.no_pending_secret") if otp_secret_plain.blank?
    raise I18n.t("two_factor.invalid_code") unless verify_otp_code(code)

    codes = generate_backup_code_list
    self.otp_enabled_at = Time.current
    self.otp_backup_codes_digest = codes.map { |c| digest_backup_code(c) }
    save!
    codes
  end

  def disable_otp!(code)
    raise I18n.t("two_factor.not_enabled") unless otp_enabled?
    raise I18n.t("two_factor.invalid_code") unless verify_otp_code(code) || consume_backup_code!(code)

    clear_otp!
  end

  def regenerate_otp_backup_codes!(code)
    raise I18n.t("two_factor.not_enabled") unless otp_enabled?
    raise I18n.t("two_factor.invalid_code") unless verify_otp_code(code)

    codes = generate_backup_code_list
    update!(otp_backup_codes_digest: codes.map { |c| digest_backup_code(c) })
    codes
  end

  def verify_otp!(code)
    return false unless otp_enabled?

    verify_otp_code(code)
  end

  def verify_backup_code!(code)
    return false unless otp_enabled?

    consume_backup_code!(code)
  end

  def clear_otp!
    update!(
      otp_secret: nil,
      otp_enabled_at: nil,
      otp_backup_codes_digest: []
    )
  end

  private

  def verify_otp_code(code)
    normalized = code.to_s.gsub(/\s+/, "")
    return false if normalized.blank?

    totp&.verify(normalized, drift_behind: OTP_DRIFT, drift_ahead: OTP_DRIFT).present?
  end

  def generate_backup_code_list
    Array.new(BACKUP_CODE_COUNT) do
      raw = SecureRandom.alphanumeric(8).upcase
      "#{raw[0, 4]}-#{raw[4, 4]}"
    end
  end

  def normalize_backup_code(code)
    code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def digest_backup_code(code)
    BCrypt::Password.create(normalize_backup_code(code))
  end

  def consume_backup_code!(code)
    normalized = normalize_backup_code(code)
    return false if normalized.blank?

    digests = Array(otp_backup_codes_digest)
    digests.each_with_index do |digest, index|
      next unless BCrypt::Password.new(digest) == normalized

      digests.delete_at(index)
      update!(otp_backup_codes_digest: digests)
      return true
    rescue BCrypt::Errors::InvalidHash
      next
    end
    false
  end
end
