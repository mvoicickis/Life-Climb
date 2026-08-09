# frozen_string_literal: true

module Today
  # Builds compressed timeline segments for timed DailyTodos.
  class Timeline
    FREE_GAP_MINUTES = 60

    Segment = Struct.new(
      :type, :todo, :minutes, :starts_at, :ends_at, :index,
      keyword_init: true
    )
    Result = Struct.new(
      :segments, :unscheduled, :now_segment_index, :now_ratio, :now,
      keyword_init: true
    )

    def self.build(user:, todos:, now: Time.current)
      new(user:, todos:, now:).build
    end

    def initialize(user:, todos:, now: Time.current)
      @user = user
      @todos = Array(todos)
      @now = now
    end

    def build
      timed, unscheduled = @todos.partition(&:timed?)
      timed = timed.sort_by { |todo| [ todo.window_start_at, todo.id ] }

      segments = []
      timed.each_with_index do |todo, index|
        if index.positive?
          prev = timed[index - 1]
          gap = ((todo.window_start_at - prev.window_end_at) / 60.0).floor
          if gap >= FREE_GAP_MINUTES
            segments << Segment.new(
              type: :free,
              minutes: gap,
              starts_at: prev.window_end_at,
              ends_at: todo.window_start_at,
              index: segments.size
            )
          end
        end

        segments << Segment.new(
          type: :item,
          todo: todo,
          starts_at: todo.window_start_at,
          ends_at: todo.window_end_at,
          index: segments.size
        )
      end

      now_index, now_ratio = locate_now(segments)
      Result.new(
        segments: segments,
        unscheduled: unscheduled.sort_by { |todo| [ todo.position.to_i, todo.id ] },
        now_segment_index: now_index,
        now_ratio: now_ratio,
        now: @now
      )
    end

    private

    def locate_now(segments)
      return [ nil, 0.0 ] if segments.empty?

      segments.each do |segment|
        next if @now < segment.starts_at
        next if @now > segment.ends_at

        span = (segment.ends_at - segment.starts_at).to_f
        ratio = span <= 0 ? 0.0 : ((@now - segment.starts_at) / span).clamp(0.0, 1.0)
        return [ segment.index, ratio ]
      end

      # Before first / after last — pin to nearest edge.
      if @now < segments.first.starts_at
        [ segments.first.index, 0.0 ]
      else
        [ segments.last.index, 1.0 ]
      end
    end
  end
end
