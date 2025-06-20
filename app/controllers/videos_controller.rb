class VideosController < ApplicationController
  def index
    # Timeline control panel - get the selected day range
    @selected_days = params[:days_since_published]&.to_i || 1

    # Get available day ranges for the filter dropdown (max 1500 days)
    @available_days = VideoResultsSincePublished
      .where("days_since_published <= ?", 1500)
      .distinct
      .pluck(:days_since_published)
      .sort

    # Handle sorting parameters
    @sort_column = params[:sort] || "rank"
    @sort_direction = params[:direction] || "asc"

    # Validate sort column to prevent SQL injection
    allowed_sort_columns = %w[rank views_since_published percentile rank_change_since_day_1
                             day_over_day_rank_change rank_slope_since_day_1
                             percentile_change_since_day_1 three_day_smoothed_average_rank_change date_published]
    @sort_column = "rank" unless allowed_sort_columns.include?(@sort_column)

    # Validate sort direction
    @sort_direction = "asc" unless %w[asc desc].include?(@sort_direction)

    # Get video rankings for the selected day range with pagination and sorting
    base_query = VideoResultsSincePublished
      .includes(:video)
      .where(days_since_published: @selected_days)

    if @sort_column == "date_published"
      @video_rankings = base_query
        .joins(:video)
        .order("videos.date_published #{@sort_direction}")
        .page(params[:page])
        .per(params[:per_page] || 25)
    else
      @video_rankings = base_query
        .order(@sort_column => @sort_direction)
        .page(params[:page])
        .per(params[:per_page] || 25)
    end

    # Get total count for pagination
    @total_videos = VideoResultsSincePublished.where(days_since_published: @selected_days).count

    # Get the previous day's data for rank change calculations
    @previous_day_rankings = VideoResultsSincePublished
      .includes(:video)
      .where(days_since_published: @selected_days - 1)
      .index_by(&:video_id)
  end

  def show
    @video = Video.find(params[:id])

    # Get the selected date for daily rankings (default to today or latest available)
    @selected_date = params[:selected_date]&.to_date || @video.video_daily_rankings.maximum(:date) || Date.today

    # Get available dates for the date selector
    @available_dates = @video.video_daily_rankings.order(:date).pluck(:date)

    # Get the latest ranking data
    @latest_ranking = @video.video_results_since_published.order(:days_since_published).last

    # Get daily ranking for the selected date - calculate days since published
    if @video.date_published.present?
      days_since_published = (@selected_date - @video.date_published.to_date).to_i
      @selected_daily_ranking = @video.video_results_since_published.find_by(days_since_published: days_since_published)
    else
      @selected_daily_ranking = nil
    end

    # Get all video results since published for the performance over time chart
    @performance_over_time = @video.video_results_since_published
      .order(:days_since_published)

    # Determine available time range options based on data
    @available_time_ranges = []

    # Check if we have daily rankings data
    if @video.video_daily_rankings.any?
      earliest_date = @video.video_daily_rankings.minimum(:date)
      days_of_data = (Date.today - earliest_date).to_i if earliest_date

      @available_time_ranges << "30_days" if days_of_data && days_of_data >= 30
      @available_time_ranges << "90_days" if days_of_data && days_of_data >= 90
      @available_time_ranges << "1_year" if days_of_data && days_of_data >= 365
    end

    # Always show "since published" if we have any performance data
    @available_time_ranges << "since_published" if @performance_over_time.any?

    # If no ranges are available, default to 30 days
    @available_time_ranges = [ "30_days" ] if @available_time_ranges.empty?

    # Ensure the selected time range is available, otherwise use the first available
    @chart_time_range = params[:chart_time_range] || @available_time_ranges.first
    @chart_time_range = @available_time_ranges.first unless @available_time_ranges.include?(@chart_time_range)

    # Calculate the start date based on the selected time range
    case @chart_time_range
    when "90_days"
      @chart_start_date = 90.days.ago.to_date
    when "1_year"
      @chart_start_date = 1.year.ago.to_date
    when "since_published"
      @chart_start_date = @video.date_published&.to_date || 1.year.ago.to_date
    else # '30_days' default
      @chart_start_date = 30.days.ago.to_date
    end

    # Get daily rankings for the selected time range
    @daily_rankings = @video.video_daily_rankings
      .where("date >= ?", @chart_start_date)
      .order(:date)

    # Get view data for the selected time range
    @recent_views = @video.views
      .where("date >= ?", @chart_start_date)
      .order(:date)

    # Calculate trend insights
    if @performance_over_time.any?
      # Calculate rank trend (positive means improving rank, negative means declining)
      first_rank = @performance_over_time.first.rank
      last_rank = @performance_over_time.last.rank
      @rank_trend = first_rank - last_rank
      @rank_trend_direction = @rank_trend > 0 ? "improving" : @rank_trend < 0 ? "declining" : "stable"

      # Calculate percentile trend
      first_percentile = @performance_over_time.first.percentile
      last_percentile = @performance_over_time.last.percentile
      @percentile_trend = last_percentile - first_percentile
      @percentile_trend_direction = @percentile_trend > 0 ? "improving" : @percentile_trend < 0 ? "declining" : "stable"

      # Find peak performance day
      @peak_performance = @performance_over_time.order(:rank).first

      # Calculate average daily rank change
      rank_changes = @performance_over_time.where.not(rank_change_since_day_1: nil).pluck(:rank_change_since_day_1)
      @avg_daily_rank_change = rank_changes.any? ? rank_changes.sum.to_f / rank_changes.length : 0
    end

    # Calculate median daily views
    daily_views_array = @video.views.pluck(:single_day_views).compact.sort
    if daily_views_array.length > 0
      if daily_views_array.length.odd?
        @median_daily_views = daily_views_array[daily_views_array.length / 2]
      else
        mid = daily_views_array.length / 2
        @median_daily_views = (daily_views_array[mid - 1] + daily_views_array[mid]) / 2.0
      end
    else
      @median_daily_views = 0
    end

    # Calculate view statistics from the video table (not timeseries)
    @total_views = @video.view_count.to_i
    @avg_daily_views = @video.views.average(:single_day_views)&.round(0) || 0

    # Calculate how this video compares to all other videos in terms of total views
    @total_videos_count = Video.count
    @videos_with_more_views = Video.where("view_count > ?", @video.view_count).count
    @videos_with_less_views = Video.where("view_count < ?", @video.view_count).count
    @view_rank = @videos_with_more_views + 1
    @view_percentile = ((@total_videos_count - @view_rank + 1).to_f / @total_videos_count * 100).round(1)

    # Get max daily views and its date
    max_view_record = @video.views.where("single_day_views > 0").order(:single_day_views).last
    @max_daily_views = max_view_record&.single_day_views || 0
    @max_daily_views_date = max_view_record&.date

    # Get min daily views (excluding 0) and its date
    min_view_record = @video.views.where("single_day_views > 0").order(:single_day_views).first
    @min_daily_views = min_view_record&.single_day_views || 0
    @min_daily_views_date = min_view_record&.date

    # Get thumbnail
    @thumbnail = @video.thumbnails.first
  end
end
