class VideoDailyRanking < ApplicationRecord
  belongs_to :video

  validates :date, presence: true
  validates :cumulative_position, :cumulative_total_videos, :daily_position, :daily_total_videos, presence: true
  validates :cumulative_percentile, :daily_percentile, presence: true
  validates :cumulative_position, :daily_position, numericality: { greater_than: 0 }
  validates :cumulative_total_videos, :daily_total_videos, numericality: { greater_than: 0 }
  validates :cumulative_percentile, :daily_percentile, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :video_id, uniqueness: { scope: :date }
end
