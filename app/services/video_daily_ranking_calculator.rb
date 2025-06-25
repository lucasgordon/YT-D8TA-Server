class VideoDailyRankingCalculator
  def self.run_for_date(date)
    cumulative_videos = Video.joins(:views)
      .select("videos.*, SUM(views.daily_view_count) as cumulative_views")
      .where("views.date <= ?", date)
      .group("videos.id")
      .order(Arel.sql("SUM(views.daily_view_count) DESC"))

    daily_videos = Video.joins(:views)
      .select("videos.*, views.daily_view_count as today_views")
      .where("views.date = ?", date)
      .order(Arel.sql("views.daily_view_count DESC"))

    cumulative_total = Video.joins(:views)
      .where("views.date <= ?", date)
      .distinct
      .count

    daily_total = Video.joins(:views)
      .where("views.date = ?", date)
      .distinct
      .count

    prev_rankings = VideoDailyRanking.where(date: date - 1).index_by(&:video_id)

    upserts = []

    cumulative_videos.each_with_index do |video, idx|
      cumulative_position = idx + 1
      cumulative_percentile = ((cumulative_total - cumulative_position).to_f / cumulative_total).round(2)
      prev = prev_rankings[video.id]
      cumulative_rank_change = prev ? prev.cumulative_position - cumulative_position : nil
      cumulative_momentum = prev ? (prev.cumulative_rank_change || 0) + (cumulative_rank_change || 0) : nil

      daily_idx = daily_videos.find_index { |v| v.id == video.id }
      if daily_idx
        daily_position = daily_idx + 1
        daily_percentile = ((daily_total - daily_position).to_f / daily_total).round(2)
        prev_daily_rank_change = prev ? prev.daily_position - daily_position : nil
        daily_momentum = prev ? (prev.daily_rank_change || 0) + (prev_daily_rank_change || 0) : nil
      else
        daily_position = daily_total + 1
        daily_percentile = 0.00
        prev_daily_rank_change = nil
        daily_momentum = nil
      end

      upserts << {
        video_id: video.id,
        date: date,
        cumulative_position: cumulative_position,
        cumulative_total_videos: cumulative_total,
        cumulative_percentile: cumulative_percentile,
        cumulative_rank_change: cumulative_rank_change,
        cumulative_momentum: cumulative_momentum,
        daily_position: daily_position,
        daily_total_videos: daily_total,
        daily_percentile: daily_percentile,
        daily_rank_change: prev_daily_rank_change,
        daily_momentum: daily_momentum,
        created_at: Time.now,
        updated_at: Time.now
      }
    end

    VideoDailyRanking.upsert_all(upserts, unique_by: %i[video_id date])
  end

  def self.run_for_all_dates
    start_date = Date.new(2020, 12, 10)
    end_date = Date.today
    (start_date..end_date).each do |date|
      run_for_date(date)
    end
  end
end
