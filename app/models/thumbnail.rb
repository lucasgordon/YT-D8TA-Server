class Thumbnail < ApplicationRecord
  belongs_to :video, foreign_key: :youtube_id, primary_key: :youtube_id

  validates :youtube_id, presence: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }
  validates :status, inclusion: { in: %w[pending processing completed failed], allow_nil: true }
end
