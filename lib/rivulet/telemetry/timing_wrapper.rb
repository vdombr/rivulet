module Rivulet
  class Telemetry
    module TimingWrapper
      def call(...)
        Fiber[:rivulet_telemetry]&.start_recording(self)
        super
      ensure
        Fiber[:rivulet_telemetry]&.stop_recording(self)
      end
    end
  end
end
