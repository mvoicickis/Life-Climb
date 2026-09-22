# frozen_string_literal: true

# Tell the service worker not to snapshot HTML that includes a one-time flash.
module OfflinePageCacheHeaders
  extend ActiveSupport::Concern

  included do
    after_action :set_offline_page_cache_skip_header
  end

  private

  def set_offline_page_cache_skip_header
    return unless request.format.html?
    return unless response.successful?
    return unless flash[:notice].present? || flash[:alert].present?

    response.headers["X-LP-No-Page-Cache"] = "1"
  end
end
