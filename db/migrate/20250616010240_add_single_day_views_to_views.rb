class AddSingleDayViewsToViews < ActiveRecord::Migration[8.0]
  def change
    add_column :views, :single_day_views, :bigint
  end
end
