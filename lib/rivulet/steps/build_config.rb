module Rivulet
  module Steps
    class BuildConfig < Rivulet::Step
      def call(input)
        Rivulet::Application.setting :app do
          setting :name
        end

        Rivulet::Application.setting :database do
          setting :dsn
          setting :pool
        end

        Rivulet::Application.setting :logger, reader: true do
          setting :engine
          setting :level
        end

        Rivulet::Application.setting :sendfile do
          setting :enabled, default: false
          setting :variation, default: 'x-accel-redirect'
          setting :mappings, default: []
        end

        Rivulet::Application.setting :telemetry do
          setting :sink, default: Rivulet::Telemetry::Sink::Null.new
        end

        Success(input)
      end
    end
  end
end
