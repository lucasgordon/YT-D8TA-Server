class VideosController < ApplicationController
  def index
    # Timeline control panel - get the selected day range
    @selected_days = params[:days_since_published]&.to_i || 7

    # Get available day ranges for the filter dropdown (max 1500 days)
    @available_days = Video.available_days

    # Handle sorting parameters
    @sort_column = params[:sort] || "rank"
    @sort_direction = params[:direction] || "asc"

    # Get video rankings for the selected day range with pagination and sorting
    @video_rankings = Video.get_video_rankings(
      @selected_days,
      @sort_column,
      @sort_direction,
      params[:page],
      params[:per_page]
    )

    # Get total count for pagination
    @total_videos = Video.total_videos_for_days(@selected_days)

    # Get the previous day's data for rank change calculations
    @previous_day_rankings = Video.previous_day_rankings(@selected_days)
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
    @selected_daily_ranking = @video.selected_daily_ranking(@selected_date)

    # Get all video results since published for the performance over time chart
    @performance_over_time = @video.performance_over_time

    # Determine available time range options based on data
    @available_time_ranges = @video.available_time_ranges

    # Ensure the selected time range is available, otherwise use the first available
    @chart_time_range = params[:chart_time_range] || @available_time_ranges.first
    @chart_time_range = @available_time_ranges.first unless @available_time_ranges.include?(@chart_time_range)

    # Calculate the start date based on the selected time range
    @chart_start_date = @video.chart_start_date(@chart_time_range)

    # Get daily rankings for the selected time range
    @daily_rankings = @video.daily_rankings_for_time_range(@chart_start_date)

    # Get view data for the selected time range
    @recent_views = @video.recent_views_for_time_range(@chart_start_date)

    # Calculate trend insights
    trend_data = @video.trend_insights
    if trend_data.any?
      @rank_trend = trend_data[:rank_trend]
      @rank_trend_direction = trend_data[:rank_trend_direction]
      @percentile_trend = trend_data[:percentile_trend]
      @percentile_trend_direction = trend_data[:percentile_trend_direction]
      @peak_performance = trend_data[:peak_performance]
      @avg_daily_rank_change = trend_data[:avg_daily_rank_change]
    end

    # Calculate median daily views
    @median_daily_views = @video.median_daily_views

    # Calculate view statistics from the video table (not timeseries)
    view_stats = @video.view_statistics
    @total_views = view_stats[:total_views]
    @avg_daily_views = view_stats[:avg_daily_views]
    @total_videos_count = view_stats[:total_videos_count]
    @videos_with_more_views = view_stats[:videos_with_more_views]
    @videos_with_less_views = view_stats[:videos_with_less_views]
    @view_rank = view_stats[:view_rank]
    @view_percentile = view_stats[:view_percentile]

    # Get max daily views and its date
    max_views_data = @video.max_daily_views_data
    @max_daily_views = max_views_data[:max_daily_views]
    @max_daily_views_date = max_views_data[:max_daily_views_date]

    # Get min daily views (excluding 0) and its date
    min_views_data = @video.min_daily_views_data
    @min_daily_views = min_views_data[:min_daily_views]
    @min_daily_views_date = min_views_data[:min_daily_views_date]

    # Get thumbnail
    @thumbnail = @video.thumbnails.first
  end
end
