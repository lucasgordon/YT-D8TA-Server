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
end
