# frozen_string_literal: true

class AddReferralsToUsersAndBetaSignups < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :referral_code, :string
    add_reference :users, :referred_by, foreign_key: { to_table: :users }, index: true

    backfill_referral_codes!

    change_column_null :users, :referral_code, false
    add_index :users, :referral_code, unique: true

    add_reference :beta_signups, :referred_by, foreign_key: { to_table: :users }, index: true
  end

  def down
    remove_reference :beta_signups, :referred_by, foreign_key: { to_table: :users }
    remove_reference :users, :referred_by, foreign_key: { to_table: :users }
    remove_index :users, :referral_code
    remove_column :users, :referral_code
  end

  private

  def backfill_referral_codes!
    User.reset_column_information
    User.find_each do |user|
      next if user.referral_code.present?

      loop do
        code = generate_referral_code
        next if User.exists?(referral_code: code)

        user.update_columns(referral_code: code, updated_at: Time.current)
        break
      end
    end
  end

  def generate_referral_code
    SecureRandom.urlsafe_base64(6)
  end
end
