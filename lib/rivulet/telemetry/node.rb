module Rivulet
  class Telemetry
    Node = Struct.new(
      :name, :started_at, :ended_at, :duration_ms,
      :self_ms, :children, keyword_init: true
    )
  end
end
