require "json"
require "open3"

class Video < ApplicationRecord
  has_many :views, foreign_key: :youtube_id, primary_key: :youtube_id, dependent: :destroy
  has_many :thumbnails, foreign_key: :youtube_id, primary_key: :youtube_id, dependent: :destroy

  validates :youtube_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :watch_url, presence: true

  def self.fetch_youtube_data(two_fa_code: nil)
    script_path = Rails.root.join("lib", "python_scripts", "youtube_scraper.py")
    username = ENV["YOUTUBE_USERNAME"]
    password = ENV["YOUTUBE_PASSWORD"]

    # First check auth state
    cmd = [ "python3", script_path.to_s ]
    raw_result = `#{cmd.join(" ")} 2>&1`  # Capture both stdout and stderr

    begin
      # Find the last line that contains valid JSON
      json_line = raw_result.split("\n").reverse.find { |line| line.strip.start_with?("{") && line.strip.end_with?("}") }
      result = JSON.parse(json_line)

      case result["auth_state"]
      when "AUTHENTICATED"
        # Already authenticated, fetch data
        process_result(result)

      when "LOGIN_REQUIRED"
        # Need to provide credentials
        cmd = [ "python3", script_path.to_s, username, password ]
        raw_result = `#{cmd.join(" ")} 2>&1`
        json_line = raw_result.split("\n").reverse.find { |line| line.strip.start_with?("{") && line.strip.end_with?("}") }
        result = JSON.parse(json_line)
        process_result(result)

      when "2FA_REQUIRED"
        if two_fa_code
          # We have the 2FA code, use it with the saved challenge URL
          cmd = [ "python3", script_path.to_s, username, password, two_fa_code ]
          raw_result = `#{cmd.join(" ")} 2>&1`
          json_line = raw_result.split("\n").reverse.find { |line| line.strip.start_with?("{") && line.strip.end_with?("}") }
          result = JSON.parse(json_line)
          process_result(result)
        else
          # Return the 2FA required state and challenge URL
          result
        end

      else
        puts "Unexpected auth_state: #{result["auth_state"].inspect}"
        puts "Full result: #{result.inspect}"
        raise "Unknown authentication state: #{result["auth_state"]}"
      end
    rescue JSON::ParserError => e
      puts "Failed to parse JSON from script output:"
      puts "Raw output was: #{raw_result}"
      raise "Failed to parse script output: #{e.message}"
    end
  end

  private

  def self.process_result(result)
    # Log script messages
    if result["messages"]
      puts "Script messages:"
      result["messages"].each do |msg|
        puts "  - #{msg}"
      end
    end

    if result["error"]
      raise "Python script error: #{result['error']}"
    end

    # Process the data
    if result["videos"]
      result["videos"].each do |video_data|
        video = find_or_initialize_by(youtube_id: video_data["youtube_id"])
        video.assign_attributes(
          title: video_data["title"],
          description: video_data["description"],
          date_published: Time.at(video_data["date_published"].to_i),
          channel_id: video_data["channel_id"],
          draft_status: video_data["draft_status"],
          length_seconds: video_data["length_seconds"],
          time_created_seconds: video_data["time_created_seconds"],
          watch_url: video_data["watch_url"],
          user_set_monetization: video_data["user_set_monetization"],
          ad_friendly_review_decision: video_data["ad_friendly_review_decision"],
          view_count: video_data["view_count"],
          comment_count: video_data["comment_count"],
          like_count: video_data["like_count"],
          external_view_count: video_data["external_view_count"],
          is_shorts_renderable: video_data["is_shorts_renderable"]
        )
        video.save!

        # Process views data
        puts "views: #{result["views"]["youtube_id"]}"
        if result["views"] && result["views"][video_data["youtube_id"]]
          result["views"][video_data["youtube_id"]].each do |view_data|
            # Find the video by the youtube_id from the views data
            video = find_by(youtube_id: video_data["youtube_id"])
            next unless video  # Skip if video not found

            view = video.views.find_or_initialize_by(date: view_data["date"])
            view.assign_attributes(
              millis_data: view_data["millis_data"],
              daily_view_count: view_data["daily_view_count"]
            )
            view.save!
          end
        end
      end
    end

    result
  end
end
