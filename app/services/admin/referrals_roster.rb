# frozen_string_literal: true

module Admin
  # Referrer cards + app-wide referral totals. Bulk queries only.
  class ReferralsRoster
    ACTIVE_DAYS = 7

    Summary = Data.define(:referrers, :accounts, :beta_emails, :first_wins)
    AccountRow = Data.define(:user, :first_battle_at)
    BetaRow = Data.define(:signup)
    ReferrerCard = Data.define(
    :referrer,
    :referral_url,
    :accounts_count,
    :beta_count,
    :first_wins_count,
    :active_7d_count,
    :total_brought,
    :account_rows,
    :beta_rows
  )

    def self.call
      new.call
    end

    def call
      referred_users = User.where.not(referred_by_id: nil).to_a
      beta_signups = BetaSignup.where.not(referred_by_id: nil).to_a
      referred_emails = referred_users.map { |u| u.email_address.downcase }.to_set

      users_by_referrer = referred_users.group_by(&:referred_by_id)
      beta_by_referrer = beta_signups.group_by(&:referred_by_id)
      referrer_ids = (users_by_referrer.keys + beta_by_referrer.keys).uniq

      referred_ids = referred_users.map(&:id)
      first_battles = first_battle_by_user(referred_ids)
      referrers_by_id = User.where(id: referrer_ids).index_by(&:id)

      active_on_or_after = Date.current - ACTIVE_DAYS

      cards = referrer_ids.filter_map do |referrer_id|
        referrer = referrers_by_id[referrer_id]
        next unless referrer

        account_users = users_by_referrer[referrer_id] || []
        pending_betas = (beta_by_referrer[referrer_id] || []).reject do |signup|
          referred_emails.include?(signup.email.downcase)
        end

        account_rows = account_users.sort_by(&:created_at).map do |user|
          AccountRow.new(user: user, first_battle_at: first_battles[user.id])
        end

        first_wins = account_rows.count { |row| row.first_battle_at.present? }
        active_7d = account_users.count do |user|
          user.last_opened_on.present? && user.last_opened_on >= active_on_or_after
        end

        ReferrerCard.new(
          referrer: referrer,
          referral_url: referral_url_for(referrer),
          accounts_count: account_users.size,
          beta_count: pending_betas.size,
          first_wins_count: first_wins,
          active_7d_count: active_7d,
          total_brought: account_users.size + pending_betas.size,
          account_rows: account_rows,
          beta_rows: pending_betas.sort_by(&:created_at).map { |signup| BetaRow.new(signup: signup) }
        )
      end

      cards.sort_by! { |card| [ -card.total_brought, card.referrer.id ] }

      {
        summary: Summary.new(
          referrers: cards.size,
          accounts: referred_users.size,
          beta_emails: beta_signups.size,
          first_wins: first_battles.size
        ),
        cards: cards
      }
    end

    private

    def referral_url_for(user)
      code = ERB::Util.url_encode(user.referral_code.to_s)
      "#{CanonicalHost.base_url}/?r=#{code}"
    end

    def first_battle_by_user(user_ids)
      return {} if user_ids.empty?

      sources = [
        Mission.where(user_id: user_ids).where.not(completed_at: nil).group(:user_id).minimum(:completed_at),
        DailyTodo.where(user_id: user_ids).where.not(completed_at: nil).group(:user_id).minimum(:completed_at),
        StrategyGoal.battles.where(user_id: user_ids).where.not(completed_at: nil).group(:user_id).minimum(:completed_at)
      ]

      merged = {}
      sources.each do |rows|
        rows.each do |user_id, completed_at|
          next if completed_at.blank?

          merged[user_id] = [ merged[user_id], completed_at ].compact.min
        end
      end
      merged
    end
  end
end