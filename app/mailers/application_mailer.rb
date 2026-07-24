class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "LifePoints <noreply@lifepoints.onrender.com>") }
  layout "mailer"
end
