module ApplicationHelper
  def time_ago_in_words_custom(date)
    return "-" unless date

    # Convert to Date object if it's a Time object or string
    if date.is_a?(Time)
      date = date.to_date
    elsif date.is_a?(String)
      date = Date.parse(date)
    end

    now = Date.today
    days = (now - date).to_i
    if days < 1
      "Today"
    elsif days == 1
      "1 day ago"
    elsif days < 30
      "#{days} days ago"
    elsif days < 365
      months = (days / 30.0).round
      months == 1 ? "1 month ago" : "#{months} months ago"
    else
      years = (days / 365.0).round
      years == 1 ? "1 year ago" : "#{years} years ago"
    end
  end
end
