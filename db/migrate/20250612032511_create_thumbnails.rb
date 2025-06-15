class CreateThumbnails < ActiveRecord::Migration[8.0]
  def change
    create_table :thumbnails do |t|
      t.string :youtube_id, null: false
      t.string :url, null: false
      t.string :status

      t.timestamps
    end

    add_index :thumbnails, :youtube_id
    add_foreign_key :thumbnails, :videos, column: :youtube_id, primary_key: :youtube_id
  end
end
