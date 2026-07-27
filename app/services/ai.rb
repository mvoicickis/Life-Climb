# frozen_string_literal: true

module Ai
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TimeoutError < Error; end
  class ResponseError < Error; end
end
