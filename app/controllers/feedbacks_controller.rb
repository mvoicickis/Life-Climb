class FeedbacksController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  skip_onboarding_check only: %i[new create]

  def new
    @feedback = Feedback.new(
      page_context: feedback_page_context,
      app_version: resolved_app_version,
      rating: params[:rating],
      ok_to_contact: false,
      contact_info: default_contact_info
    )
  end

  def create
    @feedback = Feedback.new(feedback_params)
    @feedback.user = current_user if authenticated?
    @feedback.page_context = resolved_page_context if @feedback.page_context.blank?
    @feedback.app_version = resolved_app_version if @feedback.app_version.blank?

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
    params.require(:feedback).permit(:body, :rating, :page_context, :app_version, :ok_to_contact, :contact_info)
  end

  def default_contact_info
    return nil unless authenticated?

    current_user.email_address.to_s.presence
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

  def resolved_app_version
    explicit = params.dig(:feedback, :app_version).presence
    return explicit.to_s.truncate(7) if explicit.present?

    APP_VERSION
  end

  def after_feedback_path
    return dashboard_path if authenticated?

    root_path
  end
end
