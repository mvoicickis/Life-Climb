# frozen_string_literal: true

module FirstTipsHelper
  def first_tip_layer_config(page)
    if Rails.env.development? && params[:tip].present?
      preview = first_tip_preview_config
      return preview if preview && first_tip_preview_active?(page)
    end

    return unless @first_tip.is_a?(Hash)

    @first_tip
  end

  def first_tip_guide_path(user = current_user)
    image_path(hero_animal_image_path(user))
  end

  def first_tip_bubble_copy(key)
    key = key.to_s
    if Rails.env.development? && params[:tip].to_s == "finish" && key == "finish"
      return t("dev.first_tips.finish.html")
    end

    t("first_tips.#{key}.html")
  end
end
