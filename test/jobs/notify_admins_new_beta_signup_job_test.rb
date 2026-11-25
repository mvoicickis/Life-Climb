# frozen_string_literal: true

require "test_helper"

class NotifyAdminsNewBetaSignupJobTest < ActiveJob::TestCase
  setup do
    @admin = users(:admin)
    @member = users(:one)
    PushSubscription.where(user: [ @admin, @member ]).delete_all
    @admin_sub = create_push_subscription!(@admin)
    @member_sub = create_push_subscription!(@member)
    @admin.update!(admin: true)
    @member.update!(admin: false)
  end

  test "enqueues one SendWebPushJob per admin with subscriptions" do
    second_admin = User.create!(
      email_address: "second-admin@example.com",
      name: "Second",
      password: "password12345",
      admin: true
    )
    create_push_subscription! second_admin

    signup = BetaSignup.create!(email: "new@example.com", device: "iphone")

    assert_enqueued_jobs 2, only: SendWebPushJob do
      NotifyAdminsNewBetaSignupJob.perform_now(signup.id)
    end

    admin_ids = enqueued_jobs.filter_map do |job|
      next unless job["job_class"] == "SendWebPushJob"

      user_id, = ActiveJob::Arguments.deserialize(job["arguments"])
      user_id
    end
    assert_equal [ @admin.id, second_admin.id ].sort, admin_ids.sort
    refute_includes admin_ids, @member.id
  end

  test "skips admins without push subscriptions" do
    @admin_sub.destroy!
    signup = BetaSignup.create!(email: "quiet@example.com")

    assert_no_enqueued_jobs only: SendWebPushJob do
      NotifyAdminsNewBetaSignupJob.perform_now(signup.id)
    end
  end

  test "payload includes kind url tag and email body" do
    signup = BetaSignup.create!(email: "notify@example.com", device: "iphone")

    NotifyAdminsNewBetaSignupJob.perform_now(signup.id)

    job = enqueued_jobs.find { |j| j["job_class"] == "SendWebPushJob" }
    assert job
    user_id, payload = ActiveJob::Arguments.deserialize(job["arguments"])
    assert_equal @admin.id, user_id
    assert_equal I18n.t("notifications.admin_beta_signup_push.title"), payload["title"]
    assert_equal "notify@example.com", payload["body"]
    assert_equal "/admin/beta_signups", payload["url"]
    assert_equal "admin_beta_signup", payload["kind"]
    assert_equal "beta-signup-#{signup.id}", payload["tag"]
  end

  test "android device appends suffix to body" do
    signup = BetaSignup.create!(email: "droid@example.com", device: "android")

    NotifyAdminsNewBetaSignupJob.perform_now(signup.id)

    job = enqueued_jobs.find { |j| j["job_class"] == "SendWebPushJob" }
    _user_id, payload = ActiveJob::Arguments.deserialize(job["arguments"])
    assert_equal "droid@example.com · Android", payload["body"]
  end

  test "admin recipient scope does not use DISTINCT" do
    sql = NotifyAdminsNewBetaSignupJob.new.send(:admin_recipients).to_sql
    refute_match(/\bDISTINCT\b/i, sql)
  end

  test "missing signup does nothing" do
    assert_no_enqueued_jobs only: SendWebPushJob do
      NotifyAdminsNewBetaSignupJob.perform_now(-1)
    end
  end

  private

  def create_push_subscription!(user)
    PushSubscription.create!(
      user: user,
      endpoint: "https://fcm.googleapis.com/fcm/send/#{user.id}-#{SecureRandom.hex(4)}",
      p256dh: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTsHJQDSiUC_nNAw0QQxmlYjXz12WA0NedmzVoY_o0U0K2pU",
      auth: "tBHItJI5svbpez7KI4CCXg"
    )
  end
end
