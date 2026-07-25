class RemapLifeAreaKeysToTree < ActiveRecord::Migration[8.1]
  OLD_TO_NEW = {
    "creativity" => "love",
    "group" => "community",
    "species" => "humanity",
    "life_forms" => "animals",
    "physical_universe" => "physical_world"
  }.freeze

  TREE = %w[
    love
    family
    community
    humanity
    animals
    nature
    physical_world
  ].freeze

  def up
    # Rename legacy keys in place
    OLD_TO_NEW.each do |from, to|
      execute <<-SQL.squish
        UPDATE life_areas SET key = '#{to}' WHERE key = '#{from}'
      SQL
    end

    # Move former "self" content onto a new family row when family is missing,
    # otherwise keep self until we drop it after ensuring tree keys.
    say_with_time "ensure tree keys per dream" do
      dream_ids = select_values("SELECT DISTINCT dream_id FROM life_areas")
      dream_ids.each do |dream_id|
        user_id = select_value("SELECT user_id FROM life_areas WHERE dream_id = #{dream_id} LIMIT 1")
        next unless user_id

        TREE.each_with_index do |key, index|
          exists = select_value("SELECT id FROM life_areas WHERE dream_id = #{dream_id} AND key = '#{key}' LIMIT 1")
          next if exists

          execute <<-SQL.squish
            INSERT INTO life_areas (user_id, dream_id, key, number, position, closer_score, ambition, present_scene, meta, created_at, updated_at)
            VALUES (#{user_id}, #{dream_id}, '#{key}', #{index + 1}, #{index}, 1, NULL, NULL, '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
        end

        # Re-number tree rows
        TREE.each_with_index do |key, index|
          execute <<-SQL.squish
            UPDATE life_areas
            SET number = #{index + 1}, position = #{index}, updated_at = CURRENT_TIMESTAMP
            WHERE dream_id = #{dream_id} AND key = '#{key}'
          SQL
        end
      end
    end

    # Point goals that used "self" at love when possible, then remove self rows
    execute <<-SQL.squish
      UPDATE goals
      SET life_area_id = (
        SELECT love.id FROM life_areas love
        INNER JOIN life_areas old_self ON old_self.dream_id = love.dream_id
        WHERE old_self.id = goals.life_area_id
          AND old_self.key = 'self'
          AND love.key = 'love'
        LIMIT 1
      )
      WHERE life_area_id IN (SELECT id FROM life_areas WHERE key = 'self')
    SQL

    execute "DELETE FROM life_areas WHERE key = 'self'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
