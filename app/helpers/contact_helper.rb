module ContactHelper
  # Direct founder contact for Feedback. Override with Render env vars (no shell needed).
  def contact_email
    ENV.fetch("CONTACT_EMAIL", ENV.fetch("FEEDBACK_TO_EMAIL", "mvoicickis@gmail.com"))
  end

  # WhatsApp number with country code, digits only (example: 37120000000).
  # Set CONTACT_WHATSAPP in Render Environment to show the WhatsApp button.
  def contact_whatsapp_number
    ENV["CONTACT_WHATSAPP"].to_s.gsub(/\D/, "").presence
  end

  def contact_whatsapp?
    contact_whatsapp_number.present?
  end

  def contact_whatsapp_url(prefill: nil)
    return nil unless contact_whatsapp?

    text = prefill.presence || "Hi! I'm using LifePoints and wanted to share feedback:"
    "https://wa.me/#{contact_whatsapp_number}?text=#{ERB::Util.url_encode(text)}"
  end

  def contact_mailto_url
    subject = ERB::Util.url_encode("LifePoints feedback")
    body = ERB::Util.url_encode("Hi Mareks,\n\nI'm using LifePoints and wanted to share:\n\n")
    "mailto:#{contact_email}?subject=#{subject}&body=#{body}"
  end
end
