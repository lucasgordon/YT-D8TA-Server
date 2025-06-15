class View < ApplicationRecord
  belongs_to :video, foreign_key: :youtube_id, primary_key: :youtube_id

  validates :youtube_id, presence: true
  validates :date, presence: true
  validates :daily_view_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :millis_data, numericality: { only_integer: true }, allow_nil: true
  validates :youtube_id, uniqueness: { scope: :date, message: "already has a view record for this date" }
end
