# frozen_string_literal: true

class MakeUserEventsUserOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :user_events, :user_id, true
  end
end
