class AddCharacterToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :character, :string
  end
end
