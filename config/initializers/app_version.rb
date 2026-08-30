# frozen_string_literal: true

APP_VERSION = ENV["RENDER_GIT_COMMIT"].presence&.first(7) || "dev"
