# frozen_string_literal: true

module Auth
  class GoogleSignIn
    PROVIDER = OauthIdentity::GOOGLE

    Result = Data.define(:ok?, :user, :new_account, :reason)

    def self.call(auth_hash)
      new(auth_hash).call
    end

    def initialize(auth_hash)
      @auth_hash = normalize_auth_hash(auth_hash)
    end

    def call
      unless email_verified?
        return Result.new(ok?: false, user: nil, new_account: false, reason: :email_unverified)
      end

      identity = OauthIdentity.find_by(provider: PROVIDER, uid: google_uid)
      if identity
        return Result.new(ok?: true, user: identity.user, new_account: false, reason: nil)
      end

      existing = User.find_by(email_address: normalized_email)
      if existing
        user = link_existing_user!(existing)
        return Result.new(ok?: true, user: user, new_account: false, reason: nil)
      end

      user = create_user_and_identity!
      Result.new(ok?: true, user: user, new_account: true, reason: nil)
    end

    private

    def normalize_auth_hash(auth_hash)
      auth_hash.respond_to?(:to_hash) ? auth_hash.to_hash : auth_hash
    end

    def google_uid
      raw_info["sub"].presence || @auth_hash["uid"].to_s.presence
    end

    def raw_info
      extra = @auth_hash["extra"] || {}
      extra["raw_info"] || extra[:raw_info] || {}
    end

    def info
      @auth_hash["info"] || {}
    end

    def email_verified?
      verified = raw_info["email_verified"]
      verified = info["email_verified"] if verified.nil?
      ActiveModel::Type::Boolean.new.cast(verified)
    end

    def raw_email
      raw_info["email"].presence || info["email"].to_s
    end

    def normalized_email
      User.normalize_value_for(:email_address, raw_email)
    end

    def google_name
      name = info["name"].presence || raw_info["name"].to_s.strip
      name.presence || normalized_email.to_s.split("@").first
    end

    def link_existing_user!(user)
      User.transaction do
        OauthIdentity.create!(
          user: user,
          provider: PROVIDER,
          uid: google_uid,
          email: normalized_email
        )
      end
      user
    end

    def create_user_and_identity!
      User.transaction do
        user = User.create!(
          name: google_name,
          email_address: normalized_email,
          password: SecureRandom.hex(32),
          character: "fox"
        )
        user.mark_companion_pick_done!
        OauthIdentity.create!(
          user: user,
          provider: PROVIDER,
          uid: google_uid,
          email: normalized_email
        )
        user
      end
    end
  end
end
