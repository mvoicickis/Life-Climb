module ContactHelper
  # Direct founder contact for Feedback. Override with Render env vars if needed.
  DEFAULT_CONTACT_EMAIL = "mvoicickis@gmail.com"
  DEFAULT_CONTACT_WHATSAPP = "353872346580" # +353 87 234 6580

  def contact_email
    ENV.fetch("CONTACT_EMAIL", ENV.fetch("FEEDBACK_TO_EMAIL", DEFAULT_CONTACT_EMAIL))
  end

  # WhatsApp number with country code, digits only.
  def contact_whatsapp_number
    raw = ENV.fetch("CONTACT_WHATSAPP", DEFAULT_CONTACT_WHATSAPP)
    raw.to_s.gsub(/\D/, "").presence
  end

  def contact_whatsapp?
    contact_whatsapp_number.present?
  end

  def contact_whatsapp_url(prefill: nil)
    return nil unless contact_whatsapp?

    text = prefill.presence || "Hi! I'm using LifePoints and wanted to share feedback:"
    "https://wa.me/#{contact_whatsapp_number}?text=#{ERB::Util.url_encode(text)}"
  end

  def contact_mailto_url(prefill: nil)
    subject = ERB::Util.url_encode("LifePoints — Talk to Coach")
    body = ERB::Util.url_encode(prefill.presence || "Hi Mareks,\n\nI'm using LifePoints and wanted to share:\n\n")
    "mailto:#{contact_email}?subject=#{subject}&body=#{body}"
  end

  def coach_prefill_for(user)
    building = user.focus_building
    dream = building&.dream&.title || user.active_dream&.title || "—"
    goal = building&.goal&.title || user.primary_goal&.title || "—"
    building_title = building&.title || "—"
    I18n.t("coach.prefill", dream: dream, goal: goal, building: building_title)
  end

  def coach_whatsapp_url(user)
    contact_whatsapp_url(prefill: coach_prefill_for(user))
  end

  def coach_mailto_url(user)
    contact_mailto_url(prefill: coach_prefill_for(user))
  end
end
