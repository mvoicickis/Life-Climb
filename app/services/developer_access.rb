# frozen_string_literal: true

# Developer access via DB flag and/or env email whitelist.
#
# Configure with:
#   DEVELOPER_EMAIL=you@example.com
#   DEVELOPER_EMAILS=you@example.com,other@example.com
# and/or set users.developer = true in the app.
module DeveloperAccess
  module_function

  def emails
    raw = [ ENV["DEVELOPER_EMAIL"], ENV["DEVELOPER_EMAILS"] ].compact.join(",")
    raw.split(/[,\s]+/).map { |e| e.strip.downcase }.reject(&:blank?).uniq
  end

  def email_allowed?(email)
    address = email.to_s.strip.downcase.presence
    return false if address.blank?

    emails.include?(address)
  end

  def allowed?(user)
    return false if user.blank?

    user.read_attribute(:developer) == true || email_allowed?(user.email_address)
  end
end
