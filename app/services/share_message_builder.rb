require "zlib"

# Builds personalized LifePoints share copy from a habit's latest day.
# Keep platform URLs out of this class — UI/JS owns how each network receives the text.
class ShareMessageBuilder
  ENCOURAGEMENTS = [
    "Small improvements every day make a big difference.",
    "Every step gets me closer to a better version of myself.",
    "Small actions repeated every day create big results.",
    "Learning something every day adds up over time.",
    "Consistency beats intensity — one day at a time."
  ].freeze

  CLOSERS = [
    "I'm using LifePoints to become a better version of myself.",
    "I'm tracking my progress with LifePoints.",
    "I'm using LifePoints to stay consistent.",
    "I'm becoming better than yesterday with LifePoints."
  ].freeze

  LANGUAGE_HINTS = /
    german|spanish|french|italian|portuguese|japanese|chinese|korean|
    dutch|swedish|norwegian|polish|latvian|lithuanian|russian|arabic|hebrew|
    language|vocab
  /xi

  def initialize(habit, landing_url:)
    @habit = habit
    @landing_url = landing_url
  end

  def call
    [ body, "", "Try it:", @landing_url ].join("\n")
  end

  def body
    [ headline, "", encouragement, "", closer ].join("\n")
  end

  def headline
    "#{emoji} Today I #{activity_phrase}."
  end

  def encouragement
    pick(ENCOURAGEMENTS)
  end

  def closer
    pick(CLOSERS)
  end

  private

  attr_reader :habit, :landing_url

  def amount
    value = habit.today_amount
    value = 0 if value.blank?
    if value == value.to_i
      ActiveSupport::NumberHelper.number_to_delimited(value.to_i)
    else
      value.to_s("F")
    end
  end

  def unit
    habit.unit.to_s.strip
  end

  def name
    habit.name.to_s.strip
  end

  def unit_key
    unit.downcase
  end

  def name_key
    name.downcase
  end

  def emoji
    return "🚶" if walking?
    return "📚" if reading?
    return "💪" if strength?
    return "🇩🇪" if german?
    return "🧠" if studying?
    return "💧" if hydration?
    return "😴" if sleep?
    return "🥗" if nutrition?
    "✨"
  end

  def activity_phrase
    if walking?
      "walked #{amount} #{unit.presence || "steps"}"
    elsif reading?
      "read #{amount} #{unit.presence || "pages"}#{reading_subject}"
    elsif strength?
      "completed #{amount} #{unit.presence || "reps"}"
    elsif studying?
      "studied #{study_subject} for #{amount} #{unit.presence || "minutes"}"
    elsif hydration?
      "drank #{amount} #{unit.presence || "glasses"}"
    elsif sleep?
      "slept #{amount} #{unit.presence || "hours"}"
    else
      "logged #{amount} #{unit} for #{name}"
    end
  end

  def reading_subject
    subject = name
      .gsub(/\b(pages?|reading|read|books?)\b/i, "")
      .gsub(/\A[[:space:][:punct:]]+|[[:space:][:punct:]]+\z/, "")
      .presence
    subject ? " of #{subject}" : ""
  end

  def study_subject
    cleaned = name
      .gsub(/\b(study|studied|learning|practice|minutes?|mins?)\b/i, "")
      .gsub(/\A[[:space:][:punct:]]+|[[:space:][:punct:]]+\z/, "")
      .presence
    cleaned || name
  end

  def walking?
    unit_key.match?(/step/) || name_key.match?(/walk|step|run|jog/)
  end

  def reading?
    unit_key.match?(/page|chapter|book/) || name_key.match?(/read|page|book/)
  end

  def strength?
    unit_key.match?(/rep|push|pull|squat/) || name_key.match?(/push.?up|pull.?up|squat|workout|gym|lift/)
  end

  def german?
    name_key.include?("german")
  end

  def studying?
    return true if LANGUAGE_HINTS.match?(name_key)

    unit_key.match?(/min|hour/) && name_key.match?(/study|learn|lesson/)
  end

  def hydration?
    unit_key.match?(/glass|liter|litre|ml|oz/) || name_key.match?(/water|hydrat/)
  end

  def sleep?
    name_key.match?(/sleep/) || (unit_key.match?(/hour/) && name_key.match?(/sleep|rest|bed/))
  end

  def nutrition?
    name_key.match?(/calorie|meal|nutrition|veg|fruit/)
  end

  def pick(list)
    list[stable_index % list.length]
  end

  def stable_index
    Zlib.crc32("#{name}|#{unit}")
  end
end
