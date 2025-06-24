class CreateVideoResultsSincePublished < ActiveRecord::Migration[8.0]
  def change
    create_table :video_results_since_published do |t|
      t.references :video, null: false, foreign_key: true
      t.integer :days_since_published, null: false
      t.bigint :views_since_published, null: false
      t.integer :rank, null: false
      t.integer :total_videos, null: false
      t.float :percentile, null: false
      t.integer :rank_change_since_day_1
      t.integer :day_over_day_rank_change
      t.float :rank_slope_since_day_1
      t.float :percentile_change_since_day_1
      t.integer :three_day_smoothed_average_rank_change

      t.timestamps
    end

    add_index :video_results_since_published, :days_since_published
    add_index :video_results_since_published, [ :video_id, :days_since_published ], unique: true, name: 'index_video_results_on_video_and_days'
  end
end
