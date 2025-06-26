require "net/http"
require "uri"
require "fileutils"

class Thumbnail < ApplicationRecord
  belongs_to :video, foreign_key: :youtube_id, primary_key: :youtube_id

  validates :youtube_id, presence: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }
  validates :status, inclusion: { in: %w[pending processing completed failed], allow_nil: true }

  def download_thumbnail
    return false if filename.present? && File.exist?(local_file_path)

    update!(status: "processing")

    begin
      uri = URI(url)

      # Set up HTTP request with timeout
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        # Determine file extension from content type or default to jpg
        content_type = response["content-type"]
        extension = case content_type
        when /jpeg|jpg/
                     "jpg"
        when /png/
                     "png"
        when /webp/
                     "webp"
        else
                     "jpg" # default
        end

        # Generate filename using youtube_id
        new_filename = "#{youtube_id}.#{extension}"

        # Ensure the thumbnails directory exists
        FileUtils.mkdir_p(thumbnails_directory)

        # Save the file
        file_path = File.join(thumbnails_directory, new_filename)
        File.binwrite(file_path, response.body)

        # Update the record
        update!(
          filename: new_filename,
          status: "completed"
        )

        true
      else
        Rails.logger.error "HTTP error downloading thumbnail for #{youtube_id}: #{response.code} #{response.message}"
        update!(status: "failed")
        false
      end
    rescue Net::TimeoutError => e
      Rails.logger.error "Timeout downloading thumbnail for #{youtube_id}: #{e.message}"
      update!(status: "failed")
      false
    rescue => e
      Rails.logger.error "Failed to download thumbnail for #{youtube_id}: #{e.message}"
      update!(status: "failed")
      false
    end
  end

  def local_file_path
    return nil unless filename.present?
    File.join(thumbnails_directory, filename)
  end

  def asset_path
    return nil unless filename.present?
    "/thumbnails/#{filename}"
  end

  def display_url
      asset_path
  end

  def exists_locally?
    filename.present? && File.exist?(local_file_path)
  end

  private

  def thumbnails_directory
    Rails.root.join("public", "thumbnails")
  end
end
