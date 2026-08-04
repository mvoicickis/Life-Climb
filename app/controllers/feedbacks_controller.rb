class FeedbacksController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  skip_onboarding_check only: %i[new create]

  def new
    @feedback = Feedback.new(
      page_context: feedback_page_context,
      rating: params[:rating]
    )
  end

  def create
    @feedback = Feedback.new(feedback_params)
    @feedback.user = current_user if authenticated?
    @feedback.page_context = resolved_page_context if @feedback.page_context.blank?

    if @feedback.save
      begin
        FeedbackMailer.submission(@feedback).deliver_later
      rescue StandardError
        # Mail delivery must never block feedback capture during testing.
      end
      redirect_to after_feedback_path, notice: t("feedback.thanks")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:body, :rating, :page_context)
  end

  def feedback_page_context
    resolved_page_context
  end

  def resolved_page_context
    explicit = params.dig(:feedback, :page_context).presence || params[:page].presence
    return explicit.to_s.truncate(200) if explicit.present?

    referer = request.referer
    return nil if referer.blank?

    uri = URI.parse(referer)
    path = [ uri.path, uri.query ].compact.join("?")
    path.presence&.truncate(200)
  rescue URI::InvalidURIError
    nil
  end

  def after_feedback_path
    return dashboard_path if authenticated?

    root_path
  end
end
