class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Life Climb <noreply@lifeclimb.app>") }
  layout "mailer"
end
