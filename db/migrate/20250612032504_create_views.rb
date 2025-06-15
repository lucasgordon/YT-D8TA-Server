class CreateViews < ActiveRecord::Migration[8.0]
  def change
    create_table :views do |t|
      t.string :youtube_id, null: false
      t.string :date, null: false
      t.integer :millis_data
      t.integer :daily_view_count

      t.timestamps
    end

    add_index :views, :youtube_id
    add_index :views, [ :youtube_id, :date ], unique: true
    add_foreign_key :views, :videos, column: :youtube_id, primary_key: :youtube_id
  end
end
