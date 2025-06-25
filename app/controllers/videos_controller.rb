class VideosController < ApplicationController
  def index
    @selected_days = params[:days_since_published]&.to_i || 7

    @available_days = Video.available_days

    @sort_column = params[:sort] || "rank"
    @sort_direction = params[:direction] || "asc"

    @video_rankings = Video.get_video_rankings(
      @selected_days,
      @sort_column,
      @sort_direction,
      params[:page],
      params[:per_page]
    )

    @total_videos = Video.total_videos_for_days(@selected_days)

    @previous_day_rankings = Video.previous_day_rankings(@selected_days)
  end

  def show
    @video = Video.find(params[:id])

    if params[:selected_date].present?
      @selected_date = params[:selected_date].to_date
    else
      if @video.date_published.present?
        publish_date = @video.date_published.is_a?(Time) ? @video.date_published.to_date : @video.date_published.to_date
        day_7_date = publish_date + 7.days
        @selected_date = day_7_date
      else
        @selected_date = @video.video_daily_rankings.maximum(:date) || Date.today
      end
    end

    @available_dates = @video.video_daily_rankings.order(:date).pluck(:date)

    @latest_ranking = @video.video_results_since_published.order(:days_since_published).last

    @selected_daily_ranking = @video.selected_daily_ranking(@selected_date)

    @performance_over_time = @video.performance_over_time

    @available_time_ranges = @video.available_time_ranges

    @chart_time_range = params[:chart_time_range] || @available_time_ranges.first
    @chart_time_range = @available_time_ranges.first unless @available_time_ranges.include?(@chart_time_range)

    @chart_start_date = @video.chart_start_date(@chart_time_range)

    @daily_rankings = @video.daily_rankings_for_time_range(@chart_start_date)

    @recent_views = @video.recent_views_for_time_range(@chart_start_date)

    trend_data = @video.trend_insights
    if trend_data.any?
      @rank_trend = trend_data[:rank_trend]
      @rank_trend_direction = trend_data[:rank_trend_direction]
      @percentile_trend = trend_data[:percentile_trend]
      @percentile_trend_direction = trend_data[:percentile_trend_direction]
      @peak_performance = trend_data[:peak_performance]
      @avg_daily_rank_change = trend_data[:avg_daily_rank_change]
    end

    @median_daily_views = @video.median_daily_views

    view_stats = @video.view_statistics
    @total_views = view_stats[:total_views]
    @avg_daily_views = view_stats[:avg_daily_views]
    @total_videos_count = view_stats[:total_videos_count]
    @videos_with_more_views = view_stats[:videos_with_more_views]
    @videos_with_less_views = view_stats[:videos_with_less_views]
    @view_rank = view_stats[:view_rank]
    @view_percentile = view_stats[:view_percentile]

    max_views_data = @video.max_daily_views_data
    @max_daily_views = max_views_data[:max_daily_views]
    @max_daily_views_date = max_views_data[:max_daily_views_date]

    min_views_data = @video.min_daily_views_data
    @min_daily_views = min_views_data[:min_daily_views]
    @min_daily_views_date = min_views_data[:min_daily_views_date]

    @thumbnail = @video.thumbnails.first
  end
end
