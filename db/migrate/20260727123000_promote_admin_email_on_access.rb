# frozen_string_literal: true

class PromoteAdminEmailOnAccess < ActiveRecord::Migration[8.0]
  def up
    # Prefer live bootstrap (email + optional password reset) over a silent flag flip.
    result = Admin::Bootstrap.ensure!
    say "Admin bootstrap: #{result.inspect}"
  end

  def down
    # no-op
  end
end
