class FeedbacksController < ApplicationController
  def new
    @feedback = current_user.feedbacks.build
  end

  def create
    @feedback = current_user.feedbacks.build(feedback_params)

    if @feedback.save
      redirect_to dashboard_path, notice: "Thanks — your feedback was sent."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:body)
  end
end
