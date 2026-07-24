module ApplicationHelper
  def canonical_base_url
    host = ENV["APP_HOST"].presence || (respond_to?(:request) ? request.host : "example.com")
    "https://#{host}"
  end

  def absolute_url(path)
    "#{canonical_base_url}#{path}"
  end

  def page_meta_title
    content_for?(:title) ? content_for(:title) : "LifePoints"
  end

  def page_meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : "Your only competition is yesterday. Track what matters with Better Than Yesterday or Healthy Range goals."
  end

  def status_tone(status)
    case status
    when :better, :perfect then :good
    when :same then :same
    else :bad
    end
  end

  def vs_yesterday_classes(status)
    case status_tone(status)
    when :good
      "border-emerald-400/80 bg-emerald-50 text-emerald-950"
    when :same
      "border-amber-300/80 bg-amber-50 text-amber-950"
    else
      "border-rose-400/80 bg-rose-50 text-rose-950"
    end
  end

  def vs_yesterday_bar_class(status)
    case status_tone(status)
    when :good then "bg-emerald-500"
    when :same then "bg-amber-400"
    else "bg-rose-500"
    end
  end

  def vs_yesterday_badge_class(status)
    case status_tone(status)
    when :good then "bg-emerald-500 text-white"
    when :same then "bg-amber-400 text-amber-950"
    else "bg-rose-500 text-white"
    end
  end

  def status_emoji(status)
    case status_tone(status)
    when :good then "🟢"
    when :same then "🟡"
    else "🔴"
    end
  end

  # Short badge text always includes meaning (not color alone).
  def status_badge_text(status)
    case status
    when :better then "Better"
    when :same then "Same"
    when :worse then "Worse"
    when :perfect then "Perfect"
    when :too_low then "Too low"
    when :too_high then "Too high"
    else status.to_s.humanize
    end
  end

  def vs_yesterday_short(status)
    "#{status_emoji(status)} #{status_badge_text(status)}"
  end

  def status_full_text(status)
    case status
    when :better then "🟢 Better than yesterday"
    when :same then "🟡 Same as yesterday"
    when :worse then "🔴 Worse than yesterday"
    when :perfect then "🟢 Within healthy range"
    when :too_low then "🔴 Below range"
    when :too_high then "🔴 Above range"
    else status.to_s.humanize
    end
  end

  def share_message_for(tracker)
    status = tracker.status
    "#{status_full_text(status)} on LifePoints — #{format_amount(tracker.today_amount)} #{tracker.unit}"
  end

  def format_amount(amount)
    amount = 0 if amount.blank?
    amount == amount.to_i ? amount.to_i.to_s : amount.to_s("F")
  end

  def home_grid_style(count)
    cols = case count
    when 1 then 1
    when 2 then 2
    when 3, 4 then 2
    when 5, 6 then 3
    when 7, 8, 9 then 3
    else 4
    end

    "grid-template-columns: repeat(#{cols}, minmax(0, 1fr));"
  end
end
