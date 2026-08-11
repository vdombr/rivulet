module Rivulet
  class Telemetry
    module Sink
      class Null
        def on_start(node, parent)
        end

        def on_stop(node)
        end

        def on_db(elapsed_ms)
        end

        def on_root(node, total_ms)
        end
      end
    end
  end
end
