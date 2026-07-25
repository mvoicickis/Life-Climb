require "zlib"

# Builds personalized LifePoints share copy from a habit's latest day.
# Keep platform URLs out of this class — UI/JS owns how each network receives the text.
class ShareMessageBuilder
  LANGUAGE_HINTS = /
    german|spanish|french|italian|portuguese|japanese|chinese|korean|
    dutch|swedish|norwegian|polish|latvian|lithuanian|russian|arabic|hebrew|
    deutsch|español|espanol|language|vocab|sprache|idioma
  /xi

  def initialize(habit, landing_url:)
    @habit = habit
    @landing_url = landing_url
  end

  def call
    [ body, "", I18n.t("share.try_it"), @landing_url ].join("\n")
  end

  def body
    [ headline, "", encouragement, "", closer ].join("\n")
  end

  def headline
    I18n.t("share.headline", emoji: emoji, activity: activity_phrase)
  end

  def encouragement
    pick(I18n.t("share.encouragements"))
  end

  def closer
    I18n.t("share.invite")
  end

  def self.invite_message(landing_url:)
    [ I18n.t("share.invite"), "", I18n.t("share.try_it"), landing_url ].join("\n")
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
      I18n.t("share.walked", amount: amount, unit: unit.presence || I18n.t("share.default_unit_steps"))
    elsif reading?
      I18n.t(
        "share.read",
        amount: amount,
        unit: unit.presence || I18n.t("share.default_unit_pages"),
        subject: reading_subject
      )
    elsif strength?
      I18n.t("share.completed", amount: amount, unit: unit.presence || I18n.t("share.default_unit_reps"))
    elsif studying?
      I18n.t(
        "share.studied",
        subject: study_subject,
        amount: amount,
        unit: unit.presence || I18n.t("share.default_unit_minutes")
      )
    elsif hydration?
      I18n.t("share.drank", amount: amount, unit: unit.presence || I18n.t("share.default_unit_glasses"))
    elsif sleep?
      I18n.t("share.slept", amount: amount, unit: unit.presence || I18n.t("share.default_unit_hours"))
    else
      I18n.t("share.logged", amount: amount, unit: unit, name: name)
    end
  end

  def reading_subject
    subject = name
      .gsub(/\b(pages?|reading|read|books?|seiten?|páginas?|paginas?|lappus.+|grāmat.+)\b/i, "")
      .gsub(/\A[[:space:][:punct:]]+|[[:space:][:punct:]]+\z/, "")
      .presence
    subject ? I18n.t("share.read_subject", subject: subject) : ""
  end

  def study_subject
    cleaned = name
      .gsub(/\b(study|studied|learning|practice|minutes?|mins?|lernen|estudiar)\b/i, "")
      .gsub(/\A[[:space:][:punct:]]+|[[:space:][:punct:]]+\z/, "")
      .presence
    cleaned || name
  end

  def walking?
    unit_key.match?(/step|schritt|paso|soļ/) || name_key.match?(/walk|step|run|jog|gehen|caminar/)
  end

  def reading?
    unit_key.match?(/page|chapter|book|seite|página|pagina|lappus/) || name_key.match?(/read|page|book|lesen|leer/)
  end

  def strength?
    unit_key.match?(/rep|push|pull|squat|wiederholung/) || name_key.match?(/push.?up|pull.?up|squat|workout|gym|lift|liegestütz|flexiones/)
  end

  def german?
    name_key.match?(/german|deutsch|vācu/)
  end

  def studying?
    return true if LANGUAGE_HINTS.match?(name_key)

    unit_key.match?(/min|hour|stunde|hora/) && name_key.match?(/study|learn|lesson|lernen|estudiar/)
  end

  def hydration?
    unit_key.match?(/glass|liter|litre|ml|oz|glas|vaso/) || name_key.match?(/water|hydrat|wasser|agua|ūdens/)
  end

  def sleep?
    name_key.match?(/sleep|schlaf|sueño|sueno|miegs/) || (unit_key.match?(/hour|stunde|hora/) && name_key.match?(/sleep|rest|bed|schlaf|sueño/))
  end

  def nutrition?
    name_key.match?(/calorie|meal|nutrition|veg|fruit|kalorien|comida/)
  end

  def pick(list)
    list = Array(list)
    list[stable_index % list.length]
  end

  def stable_index
    Zlib.crc32("#{name}|#{unit}")
  end
end
