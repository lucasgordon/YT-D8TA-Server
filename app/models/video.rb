require "json"
require "open3"

class Video < ApplicationRecord
  include ActiveRecord::Import

  has_many :views, foreign_key: :youtube_id, primary_key: :youtube_id, dependent: :destroy
  has_many :thumbnails, foreign_key: :youtube_id, primary_key: :youtube_id, dependent: :destroy
  has_many :video_daily_rankings, dependent: :destroy
  has_many :video_results_since_published, dependent: :destroy

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

  # Class methods for index action
  def self.available_days
    VideoResultsSincePublished
      .where("days_since_published <= ?", 1500)
      .distinct
      .pluck(:days_since_published)
      .sort
  end

  def self.get_video_rankings(selected_days, sort_column, sort_direction, page, per_page)
    # Validate sort column to prevent SQL injection
    allowed_sort_columns = %w[rank views_since_published percentile rank_change_since_day_1
                             day_over_day_rank_change rank_slope_since_day_1
                             percentile_change_since_day_1 three_day_smoothed_average_rank_change date_published]
    sort_column = "rank" unless allowed_sort_columns.include?(sort_column)

    # Validate sort direction
    sort_direction = "asc" unless %w[asc desc].include?(sort_direction)

    # Get video rankings for the selected day range with pagination and sorting
    base_query = VideoResultsSincePublished
      .includes(:video)
      .where(days_since_published: selected_days)

    if sort_column == "date_published"
      base_query
        .joins(:video)
        .order("videos.date_published #{sort_direction}")
        .page(page)
        .per(per_page || 25)
    else
      base_query
        .order(sort_column => sort_direction)
        .page(page)
        .per(per_page || 25)
    end
  end

  def self.total_videos_for_days(selected_days)
    VideoResultsSincePublished.where(days_since_published: selected_days).count
  end

  def self.previous_day_rankings(selected_days)
    VideoResultsSincePublished
      .includes(:video)
      .where(days_since_published: selected_days - 1)
      .index_by(&:video_id)
  end

  # Instance methods for show action
  def selected_daily_ranking(selected_date)
    return nil unless date_published.present?

    days_since_published = (selected_date - date_published.to_date).to_i
    video_results_since_published.find_by(days_since_published: days_since_published)
  end

  def performance_over_time
    video_results_since_published.order(:days_since_published)
  end

  def available_time_ranges
    ranges = []

    # Check if we have daily rankings data
    if video_daily_rankings.any?
      earliest_date = video_daily_rankings.minimum(:date)
      days_of_data = (Date.today - earliest_date).to_i if earliest_date

      ranges << "30_days" if days_of_data && days_of_data >= 30
      ranges << "90_days" if days_of_data && days_of_data >= 90
      ranges << "1_year" if days_of_data && days_of_data >= 365
    end

    # Always show "since published" if we have any performance data
    ranges << "since_published" if performance_over_time.any?

    # If no ranges are available, default to 30 days
    ranges = [ "30_days" ] if ranges.empty?

    ranges
  end

  def chart_start_date(chart_time_range)
    case chart_time_range
    when "90_days"
      90.days.ago.to_date
    when "1_year"
      1.year.ago.to_date
    when "since_published"
      date_published&.to_date || 1.year.ago.to_date
    else # '30_days' default
      30.days.ago.to_date
    end
  end

  def daily_rankings_for_time_range(chart_start_date)
    video_daily_rankings
      .where("date >= ?", chart_start_date)
      .order(:date)
  end

  def recent_views_for_time_range(chart_start_date)
    views
      .where("date >= ?", chart_start_date)
      .order(:date)
  end

  def trend_insights
    performance_data = performance_over_time
    return {} unless performance_data.any?

    # Calculate rank trend (positive means improving rank, negative means declining)
    first_rank = performance_data.first.rank
    last_rank = performance_data.last.rank
    rank_trend = first_rank - last_rank
    rank_trend_direction = rank_trend > 0 ? "improving" : rank_trend < 0 ? "declining" : "stable"

    # Calculate percentile trend
    first_percentile = performance_data.first.percentile
    last_percentile = performance_data.last.percentile
    percentile_trend = last_percentile - first_percentile
    percentile_trend_direction = percentile_trend > 0 ? "improving" : percentile_trend < 0 ? "declining" : "stable"

    # Find peak performance day
    peak_performance = performance_data.order(:rank).first

    # Calculate average daily rank change
    rank_changes = performance_data.where.not(rank_change_since_day_1: nil).pluck(:rank_change_since_day_1)
    avg_daily_rank_change = rank_changes.any? ? rank_changes.sum.to_f / rank_changes.length : 0

    {
      rank_trend: rank_trend,
      rank_trend_direction: rank_trend_direction,
      percentile_trend: percentile_trend,
      percentile_trend_direction: percentile_trend_direction,
      peak_performance: peak_performance,
      avg_daily_rank_change: avg_daily_rank_change
    }
  end

  def median_daily_views
    daily_views_array = views.pluck(:single_day_views).compact.sort
    return 0 if daily_views_array.empty?

    if daily_views_array.length.odd?
      daily_views_array[daily_views_array.length / 2]
    else
      mid = daily_views_array.length / 2
      (daily_views_array[mid - 1] + daily_views_array[mid]) / 2.0
    end
  end

  def view_statistics
    total_views = view_count.to_i
    avg_daily_views = views.average(:single_day_views)&.round(0) || 0

    # Calculate how this video compares to all other videos in terms of total views
    total_videos_count = Video.count
    videos_with_more_views = Video.where("view_count > ?", view_count).count
    videos_with_less_views = Video.where("view_count < ?", view_count).count
    view_rank = videos_with_more_views + 1
    view_percentile = ((total_videos_count - view_rank + 1).to_f / total_videos_count * 100).round(1)

    {
      total_views: total_views,
      avg_daily_views: avg_daily_views,
      total_videos_count: total_videos_count,
      videos_with_more_views: videos_with_more_views,
      videos_with_less_views: videos_with_less_views,
      view_rank: view_rank,
      view_percentile: view_percentile
    }
  end

  def max_daily_views_data
    max_view_record = views.where("single_day_views > 0").order(:single_day_views).last
    {
      max_daily_views: max_view_record&.single_day_views || 0,
      max_daily_views_date: max_view_record&.date
    }
  end

  def min_daily_views_data
    min_view_record = views.where("single_day_views > 0").order(:single_day_views).first
    {
      min_daily_views: min_view_record&.single_day_views || 0,
      min_daily_views_date: min_view_record&.date
    }
  end

  def daily_rankings
    video_daily_rankings.order(:date)
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
      # Pre-load existing videos to avoid N+1 queries
      existing_video_ids = result["videos"].map { |v| v["youtube_id"] }
      existing_videos = Video.where(youtube_id: existing_video_ids).index_by(&:youtube_id)

      # Pre-load existing views for all videos to avoid N+1 queries
      existing_views = {}
      if result["views"]
        result["views"].each do |youtube_id, view_data_array|
          dates = view_data_array.map { |v| v["date"] }
          existing_views[youtube_id] = View.where(youtube_id: youtube_id, date: dates).index_by(&:date)
        end
      end

      # Pre-load existing thumbnails
      existing_thumbnails = Thumbnail.where(youtube_id: existing_video_ids).index_by(&:youtube_id)

      # Use transaction for better performance
      ActiveRecord::Base.transaction do
        result["videos"].each do |video_data|
          # Calculate date_published first to check if we should skip this record
          date_published = Time.at(video_data["date_published"].to_i)

          # Skip videos published before 2020
          next if date_published < Time.new(2020, 1, 1)

          video_attributes = {
            youtube_id: video_data["youtube_id"],
            title: video_data["title"],
            description: video_data["description"],
            date_published: date_published,
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
          }

          if existing_videos[video_data["youtube_id"]]
            # Update existing video
            existing_videos[video_data["youtube_id"]].update!(video_attributes)
          else
            # Create new video
            Video.create!(video_attributes)
          end

          # Process thumbnail data
          if video_data["thumbnail_data"] && video_data["thumbnail_data"]["url"]
            thumbnail_attributes = {
              youtube_id: video_data["youtube_id"],
              url: video_data["thumbnail_data"]["url"]
            }

            if existing_thumbnails[video_data["youtube_id"]]
              existing_thumbnails[video_data["youtube_id"]].update!(thumbnail_attributes)
            else
              # Use find_or_initialize_by for consistency
              thumbnail = Thumbnail.find_or_initialize_by(youtube_id: video_data["youtube_id"])
              thumbnail.assign_attributes(thumbnail_attributes)
              thumbnail.save!
            end
          end

          # Process views data
          if result["views"] && result["views"][video_data["youtube_id"]]
            video_views = existing_views[video_data["youtube_id"]] || {}

            # Sort views by date and exclude the last day since we can't calculate its increment
            sorted_views = result["views"][video_data["youtube_id"]].sort_by { |v| v["date"] }
            views_to_process = sorted_views[0...-1] # Exclude the last day

            views_to_process.each do |view_data|
              # Calculate single_day_views as the difference between this day and previous day
              previous_date = (Date.parse(view_data["date"]) - 1.day).strftime("%Y-%m-%d")
              previous_view = video_views[previous_date]

              single_day_views = if previous_view && view_data["daily_view_count"].to_i > 0
                view_data["daily_view_count"].to_i - previous_view.daily_view_count.to_i
              else
                # If no previous day's data, we can't calculate the increment
                # Set to 0 instead of using the total cumulative views
                0
              end

              view_attributes = {
                youtube_id: video_data["youtube_id"],
                date: view_data["date"],
                millis_data: view_data["millis_data"],
                daily_view_count: view_data["daily_view_count"],
                single_day_views: single_day_views
              }

              if video_views[view_data["date"]]
                video_views[view_data["date"]].update!(view_attributes)
              else
                # Use find_or_initialize_by to avoid duplicate record errors
                view = View.find_or_initialize_by(youtube_id: video_data["youtube_id"], date: view_data["date"])
                view.assign_attributes(view_attributes)
                view.save!
              end
            end
          end
        end
      end
    end

    result
  end
end
