module Rivulet
  module Steps
    class LoadSettings < Rivulet::Step
      def call(input)
        app = input[:resource]
        app_file = File.expand_path('config/application.rb')
        return Failure(:settings_file_not_found) unless File.exist?(app_file)

        load app_file

        app.config.logger = app.config.logger.engine || default_logger(app)
        app.config.finalize!

        Success(input)
      end

      private

      def default_logger(app)
        Dry.Logger(app.config.logger.name, level: app.config.logger.level) do |setup|
          setup.add_backend(
            stream: $stdout,
            log_if: :debug?,
            template: '<gray>[%<severity>s]</gray> %<time>s %<message>s'
          )

          setup.add_backend(
            stream: $stdout,
            log_if: :info?,
            template: '<blue>[%<severity>s]</blue> %<time>s %<message>s'
          )

          setup.add_backend(
            stream: $stdout,
            log_if: :error?,
            template: '<red>[%<severity>s]</red> %<time>s %<message>s'
          )
        end
      end
    end
  end
end
