class AddSoundEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sound_enabled, :boolean, null: false, default: true
  end
end
