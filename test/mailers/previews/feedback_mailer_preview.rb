# Preview emails at http://localhost:3000/rails/mailers/feedback_mailer
class FeedbackMailerPreview < ActionMailer::Preview
  def submission
    FeedbackMailer.submission(Feedback.includes(:user).last || Feedback.new(
      body: "Sample feedback for preview.",
      user: User.take,
      created_at: Time.current
    ))
  end
end
