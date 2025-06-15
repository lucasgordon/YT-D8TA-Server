class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.string :youtube_id, null: false
      t.string :title
      t.text :description
      t.string :date_published
      t.string :channel_id
      t.string :draft_status
      t.string :length_seconds
      t.string :time_created_seconds
      t.string :watch_url
      t.string :user_set_monetization
      t.string :ad_friendly_review_decision
      t.string :view_count
      t.string :comment_count
      t.string :like_count
      t.string :external_view_count
      t.string :is_shorts_renderable

      t.timestamps
    end

    add_index :videos, :youtube_id, unique: true
  end
end
