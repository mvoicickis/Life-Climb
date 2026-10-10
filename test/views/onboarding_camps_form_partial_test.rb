# frozen_string_literal: true

require "test_helper"

class OnboardingCampsFormPartialTest < ActionView::TestCase
  def camps_form_locals(camp_rows:)
    {
      back_path: v2_onboarding_path(step: "goal"),
      back_label: I18n.t("v2_onboarding.back"),
      goal_title: "Become a web developer",
      camp_rows: camp_rows,
      form_url: v2_onboarding_path(step: "camps"),
      form_data: {
        turbo: false,
        onboarding_camps_target: "form",
        action: "submit->onboarding-camps#beforeSubmit"
      },
      add_input_id: "onboarding_camp_add",
      submit_label: I18n.t("v2_onboarding.start_climbing"),
      submit_data: { onboarding_camps_target: "submit" },
      setup_step_index: 2,
      setup_step_total: 2,
      data_controller: "onboarding-camps",
      extra_data: nil
    }
  end

  test "empty camp_rows shows primary add, disabled submit, and first-step placeholder" do
    html = render(partial: "shared/onboarding_camps_form", locals: camps_form_locals(camp_rows: []))
    doc = Nokogiri::HTML.fragment(html)

    assert doc.at_css("button.lp-ob-steps__add-btn.lp-ob-steps__add-btn--primary")
    submit = doc.at_css("input[type=submit].lp-cta")
    assert submit["disabled"]
    assert_nil doc.at_css("input[type=submit].lp-cta.lp-cta--ready")
    assert_equal I18n.t("v2_onboarding.camps_add_placeholder_first"), doc.at_css("#onboarding_camp_add")["placeholder"]
  end

  test "one camp row enables submit, quiets add button, and shows next-step placeholder" do
    html = render(partial: "shared/onboarding_camps_form", locals: camps_form_locals(camp_rows: [ "Get certified" ]))
    doc = Nokogiri::HTML.fragment(html)

    refute doc.at_css("button.lp-ob-steps__add-btn.lp-ob-steps__add-btn--primary")
    submit = doc.at_css("input[type=submit].lp-cta.lp-cta--ready")
    assert submit
    assert_nil submit["disabled"]
    assert_equal I18n.t("v2_onboarding.camps_add_placeholder_next"), doc.at_css("#onboarding_camp_add")["placeholder"]
  end
end
