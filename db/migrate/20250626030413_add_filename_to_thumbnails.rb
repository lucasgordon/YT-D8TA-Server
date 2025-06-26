class AddFilenameToThumbnails < ActiveRecord::Migration[8.0]
  def change
    add_column :thumbnails, :filename, :string
  end
end
