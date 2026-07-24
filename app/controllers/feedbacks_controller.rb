class FeedbacksController < ApplicationController
  def new
    @feedback = current_user.feedbacks.build
  end

  def create
    @feedback = current_user.feedbacks.build(feedback_params)

    if @feedback.save
      deliver_feedback_email(@feedback)
      redirect_to dashboard_path, notice: "Thanks — your feedback was sent."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:body)
  end

  def deliver_feedback_email(feedback)
    FeedbackMailer.submission(feedback).deliver_now
  rescue StandardError => error
    Rails.logger.error("[FeedbackMailer] #{error.class}: #{error.message}")
  end
end
