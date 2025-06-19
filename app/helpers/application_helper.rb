module ApplicationHelper
  def time_ago_in_words_custom(date)
    return "-" unless date
    date = date.is_a?(String) ? Date.parse(date) : date
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
