class AddSupportPromptFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :support_prompts_muted, :boolean, null: false, default: false
    add_column :users, :support_milestones_shown, :json, null: false, default: []
  end
end
