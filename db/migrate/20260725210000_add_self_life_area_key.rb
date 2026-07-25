class AddSelfLifeAreaKey < ActiveRecord::Migration[8.1]
  def up
    dream_ids = select_values("SELECT DISTINCT dream_id FROM life_areas")
    dream_ids.each do |dream_id|
      user_id = select_value("SELECT user_id FROM life_areas WHERE dream_id = #{dream_id} LIMIT 1")
      next unless user_id

      exists = select_value("SELECT id FROM life_areas WHERE dream_id = #{dream_id} AND key = 'self' LIMIT 1")
      next if exists

      execute <<-SQL.squish
        INSERT INTO life_areas (user_id, dream_id, key, number, position, closer_score, ambition, present_scene, meta, created_at, updated_at)
        VALUES (#{user_id}, #{dream_id}, 'self', 1, 0, 1, NULL, NULL, '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
    end

    # Re-number tree: self, love, family, community, humanity, animals, nature, physical_world
    tree = %w[self love family community humanity animals nature physical_world]
    dream_ids.each do |dream_id|
      tree.each_with_index do |key, index|
        execute <<-SQL.squish
          UPDATE life_areas
          SET number = #{index + 1}, position = #{index}, updated_at = CURRENT_TIMESTAMP
          WHERE dream_id = #{dream_id} AND key = '#{key}'
        SQL
      end
    end
  end

  def down
    execute "DELETE FROM life_areas WHERE key = 'self'"
  end
end
