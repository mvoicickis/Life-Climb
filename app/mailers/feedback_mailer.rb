class FeedbackMailer < ApplicationMailer
  def submission(feedback)
    @feedback = feedback
    @user = feedback.user
    who = @user&.email_address.presence || "anonymous visitor"

    mail(
      to: feedback_recipient,
      reply_to: @user&.email_address,
      subject: "LifePoints feedback from #{who}"
    )
  end

  private

  def feedback_recipient
    ENV.fetch("FEEDBACK_TO_EMAIL", "mvoicickis@gmail.com")
  end
end
