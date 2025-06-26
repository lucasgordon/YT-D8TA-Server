namespace :thumbnails do
  desc "Download thumbnails for videos that don't have local files"
  task download: :environment do
    puts "Starting thumbnail download process..."

    thumbnails_to_download = Thumbnail.where(filename: [ nil, "" ]).or(Thumbnail.where(status: [ "failed", nil ]))

    total_count = thumbnails_to_download.count
    puts "Found #{total_count} thumbnails to download"

    if total_count == 0
      puts "No thumbnails need downloading."
      return
    end

    success_count = 0
    failure_count = 0

    thumbnails_to_download.find_each.with_index do |thumbnail, index|
      print "Downloading thumbnail #{index + 1}/#{total_count} for video #{thumbnail.youtube_id}... "

      if thumbnail.download_thumbnail
        puts "✓ Success"
        success_count += 1
      else
        puts "✗ Failed"
        failure_count += 1
      end

      # Add a small delay to be respectful to YouTube's servers
      sleep(0.1)
    end

    puts "\nDownload complete!"
    puts "Successfully downloaded: #{success_count}"
    puts "Failed downloads: #{failure_count}"
  end

  desc "Check thumbnail status"
  task status: :environment do
    total_thumbnails = Thumbnail.count
    local_thumbnails = Thumbnail.where.not(filename: [ nil, "" ]).count
    completed_thumbnails = Thumbnail.where(status: "completed").count
    failed_thumbnails = Thumbnail.where(status: "failed").count
    pending_thumbnails = Thumbnail.where(status: [ "pending", nil ]).count

    puts "Thumbnail Status Report:"
    puts "Total thumbnails: #{total_thumbnails}"
    puts "Local files: #{local_thumbnails}"
    puts "Completed: #{completed_thumbnails}"
    puts "Failed: #{failed_thumbnails}"
    puts "Pending: #{pending_thumbnails}"
  end

  desc "Clean up failed thumbnails"
  task cleanup: :environment do
    failed_thumbnails = Thumbnail.where(status: "failed")
    count = failed_thumbnails.count

    if count == 0
      puts "No failed thumbnails to clean up."
      return
    end

    puts "Found #{count} failed thumbnails. Resetting status to allow retry..."
    failed_thumbnails.update_all(status: nil)
    puts "Cleanup complete. Run 'rake thumbnails:download' to retry failed downloads."
  end
end
