class DaysSincePublishedCalculator
  def self.calculate_all
    new.calculate_all
  end

  def calculate_all
    # Get all videos with their views, ordered by publish date
    videos = Video.includes(:views).order(:date_published)

    # Group views by days since published for each video
    video_views_by_day = {}
    videos.each do |video|
      publish_date = Date.parse(video.date_published)
      video.views.each do |view|
        view_date = Date.parse(view.date)
        days_since_published = (view_date - publish_date).to_i
        next if days_since_published <= 0 # Skip views on or before publish date

        video_views_by_day[days_since_published] ||= {}
        video_views_by_day[days_since_published][video.id] = {
          views: view.daily_view_count.to_i,
          video: video
        }
      end
    end

    # Process each day's data
    video_views_by_day.keys.sort.each do |days_since_published|
      process_day(days_since_published, video_views_by_day[days_since_published])
    end
  end

  private

  def process_day(days_since_published, day_data)
    # Sort videos by views for this day
    sorted_videos = day_data.sort_by { |_, data| -data[:views] }
    total_videos = sorted_videos.length

    # Calculate ranks and percentiles
    sorted_videos.each_with_index do |(video_id, data), index|
      rank = index + 1
      percentile = calculate_percentile(rank, total_videos)

      # Get previous day's data for this video
      previous_day_data = find_previous_day_data(video_id, days_since_published)
      day_1_data = find_day_1_data(video_id)

      # Calculate changes and metrics
      rank_change_since_day_1 = day_1_data ? day_1_data.rank - rank : nil  # Reversed to make positive = improvement
      day_over_day_rank_change = previous_day_data ? previous_day_data.rank - rank : nil  # Reversed to make positive = improvement
      rank_slope = calculate_rank_slope(rank, day_1_data&.rank, days_since_published)
      percentile_change = day_1_data ? percentile - day_1_data.percentile : nil
      three_day_avg = calculate_three_day_average(video_id, days_since_published)

      # Find or initialize the record
      record = VideoResultsSincePublished.find_or_initialize_by(
        video_id: video_id,
        days_since_published: days_since_published
      )

      # Update the record
      record.assign_attributes(
        views_since_published: data[:views],
        rank: rank,
        total_videos: total_videos,
        percentile: percentile,
        rank_change_since_day_1: rank_change_since_day_1,
        day_over_day_rank_change: day_over_day_rank_change,
        rank_slope_since_day_1: rank_slope,
        percentile_change_since_day_1: percentile_change,
        three_day_smoothed_average_rank_change: three_day_avg
      )

      record.save!
    end
  end

  def calculate_percentile(rank, total_videos)
    return 99.99 if rank == 1
    return 0.01 if rank == total_videos

    # Calculate percentile using the formula: (1 - (rank - 1)/(total_videos - 1)) * 100
    ((1 - (rank - 1).to_f / (total_videos - 1)) * 100).round(2)
  end

  def find_previous_day_data(video_id, current_day)
    return nil if current_day <= 1 # Changed from 0 to 1 since we're skipping day 0

    VideoResultsSincePublished
      .where(video_id: video_id, days_since_published: current_day - 1)
      .first
  end

  def find_day_1_data(video_id)
    VideoResultsSincePublished
      .where(video_id: video_id, days_since_published: 1)
      .first
  end

  def calculate_rank_slope(current_rank, day_1_rank, days_since_published)
    return nil unless day_1_rank && days_since_published > 1

    (day_1_rank - current_rank).to_f / (days_since_published - 1)  # Reversed to make positive = improvement
  end

  def calculate_three_day_average(video_id, current_day)
    return nil if current_day < 3

    previous_records = VideoResultsSincePublished
      .where(video_id: video_id)
      .where("days_since_published < ?", current_day)
      .order(days_since_published: :desc)
      .limit(3)
      .pluck(:day_over_day_rank_change)

    return nil if previous_records.length < 3

    # Filter out nil values and ensure we have enough records
    valid_records = previous_records.compact
    return nil if valid_records.length < 3

    (valid_records.sum.to_f / 3).round
  end
end
