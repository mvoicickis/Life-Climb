# frozen_string_literal: true

class PushSubscriptionsController < ApplicationController
  def create
    # Endpoint is unique globally — reassign if this device was subscribed under another account.
    subscription = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.assign_attributes(
      user: current_user,
      p256dh: subscription_params[:p256dh],
      auth: subscription_params[:auth],
      user_agent: request.user_agent.to_s.truncate(255),
      last_seen_at: Time.current
    )

    if subscription.save
      status = subscription.previously_new_record? ? :created : :ok
      render json: { ok: true, id: subscription.id }, status: status
    else
      render json: { ok: false, errors: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    scope = current_user.push_subscriptions
    removed =
      if params[:endpoint].present?
        scope.where(endpoint: params[:endpoint]).delete_all
      else
        scope.delete_all
      end

    render json: { ok: true, removed: removed }
  end

  def test
    unless current_user.push_subscriptions.exists?
      return render json: { ok: false, error: t("settings.reminders_no_subscription") }, status: :unprocessable_entity
    end

    SendWebPushJob.perform_later(
      current_user.id,
      {
        "title" => t("settings.reminders_test_title"),
        "body" => t("settings.reminders_test_body"),
        "url" => dashboard_path,
        "kind" => "test"
      }
    )

    render json: { ok: true }
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, :p256dh, :auth)
  end
end
