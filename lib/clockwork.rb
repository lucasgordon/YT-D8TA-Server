require "clockwork"
require "./config/boot"
require "./config/environment"

module Clockwork
  # Set timezone to EST
  configure do |config|
    config[:tz] = "America/New_York"
  end

  # Every day at 7:00 AM EST - Fetch YouTube data
  every(1.day, "fetch_youtube_data", at: "07:00") do
    puts "Starting YouTube data fetch at #{Time.current}"
    begin
      Video.fetch_youtube_data
      puts "YouTube data fetch completed successfully"
    rescue => e
      puts "Error fetching YouTube data: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end

  # Every day at 8:00 AM EST - Calculate days since published
  every(1.day, "calculate_days_since_published", at: "08:00") do
    puts "Starting days since published calculation at #{Time.current}"
    begin
      DaysSincePublishedCalculator.calculate_all
      puts "Days since published calculation completed successfully"
    rescue => e
      puts "Error calculating days since published: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end

  # Every day at 9:00 AM EST - Calculate video daily rankings
  every(1.day, "calculate_video_daily_rankings", at: "09:00") do
    puts "Starting video daily rankings calculation at #{Time.current}"
    begin
      VideoDailyRankingCalculator.run_for_all_dates
      puts "Video daily rankings calculation completed successfully"
    rescue => e
      puts "Error calculating video daily rankings: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
end
