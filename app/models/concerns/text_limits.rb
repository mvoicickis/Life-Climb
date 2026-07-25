# frozen_string_literal: true

# Shared length/presence rules for user-authored titles and short text.
module TextLimits
  TITLE_MAX = 200
  SUMMARY_MAX = 2_000
  EMAIL_MAX = 254
  PASSWORD_MIN = 12
  PASSWORD_MAX = 72 # bcrypt limit
end
