# frozen_string_literal: true

module Dashboard
  # Inline commitment_gap battle create — QuickAddToday + timed window for current_user only.
  class QuickBattlesController < ApplicationController
    include CommitmentGapRefresh

    def create
      title = params[:title].to_s.strip
      end_time = parse_end_time(params[:end_time])

      if title.blank?
        return respond_gap_error(t("strategy.next_action.commitment_gap.need_title"))
      end
      if end_time.nil?
        return respond_gap_error(t("strategy.next_action.commitment_gap.need_end_time"))
      end

      start_at = Time.current
      if end_time <= start_at
        return respond_gap_error(t("dash.timeline.end_after_start"))
      end

      result = Battles::QuickAddToday.call(user: current_user, title: title)
      todo = result.todo
      unless todo.user_id == current_user.id
        return respond_gap_error(t("strategy.next_action.commitment_gap.need_title"))
      end

      todo.start_time = start_at
      todo.end_time = end_time
      unless todo.save
        return respond_gap_error(
          todo.errors.full_messages.to_sentence.presence || t("dash.timeline.time_save_failed")
        )
      end

      refresh_commitment_gap_context!(open_reveal: params[:open_reveal].presence || "battle")
      respond_to do |format|
        format.turbo_stream { render_commitment_gap_stream }
        format.html { redirect_to dashboard_path }
      end
    rescue Battles::QuickAddToday::Error => e
      respond_gap_error(e.message)
    rescue ActiveRecord::RecordInvalid => e
      respond_gap_error(e.record.errors.full_messages.to_sentence)
    end

    private

    def parse_end_time(raw)
      value = raw.to_s.strip
      return nil if value.blank?

      if value.match?(/\A\d{1,2}:\d{2}(:\d{2})?\z/)
        parts = value.split(":").map(&:to_i)
        hour, min = parts[0], parts[1]
        return nil unless (0..23).cover?(hour) && (0..59).cover?(min)

        return Time.zone.local(
          Date.current.year, Date.current.month, Date.current.day,
          hour, min, 0
        )
      end

      Time.zone.parse(value)
    rescue ArgumentError, TypeError
      nil
    end

    def respond_gap_error(message)
      respond_to do |format|
        format.turbo_stream do
          refresh_commitment_gap_context!(open_reveal: "battle")
          flash.now[:alert] = message
          render_commitment_gap_stream
        end
        format.html { redirect_to dashboard_path, alert: message }
      end
    end
  end
end
