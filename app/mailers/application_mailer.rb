class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Life Climb <noreply@lifepoints.onrender.com>") }
  layout "mailer"
end
