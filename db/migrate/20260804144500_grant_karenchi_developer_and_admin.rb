# frozen_string_literal: true

class GrantKarenchiDeveloperAndAdmin < ActiveRecord::Migration[8.0]
  # Render free has no shell — grant access on deploy. Idempotent; other users untouched.
  def up
    results = Admin::GrantAccountAccess.ensure_all!
    results.each { |result| say "Grant account access: #{result.inspect}" }
  end

  def down
    # no-op — do not strip access on rollback
  end
end
