module Rivulet
  class Telemetry
    module SequelExtension
      def log_connection_yield(*args, &block)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        super
      ensure
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        Fiber[:rivulet_telemetry]&.record_db(elapsed)
      end
    end
  end
end

if defined?(Sequel)
  Sequel::Database.register_extension(:rivulet_telemetry) do |db|
    db.extend(Rivulet::Telemetry::SequelExtension)
  end
end
