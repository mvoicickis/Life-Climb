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
    content_for?(:meta_description) ? content_for(:meta_description) : "Track what matters. Growth stats use Up/Level/Down. Standard stats use in-range or out."
  end

  def vs_yesterday_classes(status)
    case status
    when :up, :ok
      "border-emerald-400 bg-emerald-50 text-emerald-950"
    when :level
      "border-amber-300 bg-amber-50 text-amber-950"
    else
      "border-rose-400 bg-rose-50 text-rose-950"
    end
  end

  def vs_yesterday_bar_class(status)
    case status
    when :up, :ok then "bg-emerald-500"
    when :level then "bg-amber-400"
    else "bg-rose-500"
    end
  end

  def vs_yesterday_badge_class(status)
    case status
    when :up, :ok then "bg-emerald-500 text-white"
    when :level then "bg-amber-400 text-amber-950"
    else "bg-rose-500 text-white"
    end
  end

  def vs_yesterday_short(status)
    case status
    when :up then "UP"
    when :level then "LEVEL"
    when :down then "DOWN"
    when :ok then "OK"
    when :off then "OUT"
    else status.to_s.upcase
    end
  end

  def vs_yesterday_share_word(status)
    case status
    when :up then "Up"
    when :level then "Level"
    when :down then "Down"
    when :ok then "in range"
    when :off then "out of range"
    else status.to_s
    end
  end

  def vs_yesterday_share_emoji(status)
    case status
    when :up, :ok then "🟢"
    when :level then "⚪"
    else "🔴"
    end
  end

  def share_message_for(tracker)
    status = tracker.status
    "I went #{vs_yesterday_share_word(status)} today on LifePoints #{vs_yesterday_share_emoji(status)} — #{format_amount(tracker.today_amount)} #{tracker.unit}"
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

  def good_status?(status)
    status == :up || status == :ok
  end

  def warn_status?(status)
    status == :level
  end

  def bad_status?(status)
    status == :down || status == :off
  end
end
