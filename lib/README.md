# Clockwork Scheduler

This directory contains the clockwork scheduler configuration for automated daily tasks.

## Setup

1. Install the clockwork gem (already added to Gemfile):
   ```bash
   bundle install
   ```

2. The scheduler is configured in `lib/clock.rb` and runs the following tasks daily:

   - **7:00 AM EST**: `Video.fetch_youtube_data` - Fetches latest YouTube video data
   - **8:00 AM EST**: `DaysSincePublishedCalculator.calculate_all` - Calculates performance metrics since video publication
   - **9:00 AM EST**: `VideoDailyRankingCalculator.run_for_all_dates` - Calculates daily video rankings

## Running the Scheduler

### Development
The scheduler is included in the Procfile.dev and will start automatically when you run:
```bash
bin/dev
```

### Production
To run the scheduler in production, add this to your Procfile:
```
clock: bundle exec clockwork lib/clock.rb
```

### Manual Testing
To test the scheduler manually:
```bash
bundle exec clockwork lib/clock.rb
```

## Timezone
The scheduler is configured to use Eastern Time (EST/EDT). All times are specified in EST.

## Logging
The scheduler outputs logs to stdout, including:
- Start times for each task
- Success confirmations
- Error messages with full stack traces

## Error Handling
Each task is wrapped in a begin/rescue block to prevent one failed task from stopping the entire scheduler. Errors are logged but don't stop the scheduler from continuing with other tasks. 