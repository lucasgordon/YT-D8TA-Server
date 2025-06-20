class VideoResultsSincePublished < ApplicationRecord
  self.table_name = "video_results_since_published"

  belongs_to :video

  validates :days_since_published, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :views_since_published, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rank, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :total_videos, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :percentile, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :video_id, uniqueness: { scope: :days_since_published, message: "already has results for this day" }

  # Scopes for common queries
  scope :ordered_by_days, -> { order(days_since_published: :asc) }
  scope :for_video, ->(video_id) { where(video_id: video_id) }
  scope :recent, -> { order(days_since_published: :desc) }
end
