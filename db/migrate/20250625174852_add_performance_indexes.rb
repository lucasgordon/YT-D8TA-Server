class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add index on date_published for faster filtering
    add_index :videos, :date_published

    # Add index on single_day_views for faster aggregations
    add_index :views, :single_day_views

    # Add index on daily_view_count for faster aggregations
    add_index :views, :daily_view_count

    # Add index on view_count for faster sorting and comparisons
    add_index :videos, :view_count
  end
end
