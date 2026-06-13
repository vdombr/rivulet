module Rivulet
  module Steps
    class BuildConfig < Rivulet::Step
      def call(input)
        Rivulet::Application.setting :database do
          setting :dsn
          setting :pool
        end

        Rivulet::Application.setting :logger, reader: true do
          setting :engine
          setting :name
          setting :level
        end

        Success(input)
      end
    end
  end
end
