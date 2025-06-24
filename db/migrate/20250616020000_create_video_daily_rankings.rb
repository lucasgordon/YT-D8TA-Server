class CreateVideoDailyRankings < ActiveRecord::Migration[7.0]
  def change
    create_table :video_daily_rankings do |t|
      t.references :video, null: false, foreign_key: true
      t.date :date, null: false

      # Cumulative ranking (all-time up to this date)
      t.integer :cumulative_position, null: false
      t.integer :cumulative_total_videos, null: false
      t.float :cumulative_percentile, null: false

      # Daily ranking (just for this day)
      t.integer :daily_position, null: false
      t.integer :daily_total_videos, null: false
      t.float :daily_percentile, null: false

      # Trend analysis
      t.integer :cumulative_rank_change
      t.integer :daily_rank_change
      t.integer :cumulative_momentum
      t.integer :daily_momentum

      t.timestamps
    end

    add_index :video_daily_rankings, [ :video_id, :date ], unique: true
    add_index :video_daily_rankings, :date
  end
end
