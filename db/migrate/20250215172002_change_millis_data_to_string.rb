class ChangeMillisDataToString < ActiveRecord::Migration[8.0]
  def change
    # Change millis_data to string and daily_view_count to bigint
    change_column :views, :millis_data, :string
    change_column :views, :daily_view_count, :bigint
  end
end
