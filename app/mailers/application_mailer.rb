class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Lifeclimb <noreply@lifepoints.onrender.com>") }
  layout "mailer"
end
