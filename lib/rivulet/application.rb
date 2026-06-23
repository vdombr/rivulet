module Rivulet
  class Application
    include Dry::Configurable
    include Dry::Monads[:result]
    include Dry::AutoInject(Rivulet::Container)[
      dispatch_request:       'operations.dispatch_request',
      startup_operation:      'operations.startup',
      migrate_operation:      'operations.migrate',
      run_console_operation:  'operations.run_console',
      print_routes_operation: 'operations.print_routes'
    ]

    attr_accessor :db

    def call(env)
      result = with_telemetry do
        dispatch_request.(resource: self, env: env)
      end

      return result.success[:response] if result.success?

      case result
      in Failure[:route_not_found]
        [404, { 'Content-Type' => 'text/plain' }, ['Not Found']]
      in Failure[:wrong_response_type, message]
        logger.error(message)
        [500, {}, []]
      in Failure[:conflicting_response, message]
        logger.error(message)
        [500, {}, []]
      in Failure[:file_not_found, message]
        logger.error(message)
        [500, {}, []]
      end
    end

    def routes
      @routes ||= Routing::Mapper.new([])
    end

    def startup
      startup_operation.(resource: self)
      self
    end

    def migrate!
      result = migrate_operation.(resource: self)
      if result.failure?
        warn "Migration failed: #{result.failure}"
        exit 1
      end
    end

    def run_console
      result = run_console_operation.(resource: self)
      if result.failure?
        warn "Cannot start console: #{result.failure}"
        exit 1
      end
    end

    def print_routes
      result = print_routes_operation.(resource: self)
      if result.failure?
        warn "Cannot print routes: #{result.failure}"
        exit 1
      end
    end

    private

    def with_telemetry
      t = Telemetry.new
      Fiber[:rivulet_telemetry] = t

      result = yield

      logger.info(
        "Completed total_ms=#{t.total_ms} db_ms=#{t.db_ms} flow:\n#{t.print_flow}"
      )
      result
    ensure
      Fiber[:rivulet_telemetry] = nil
    end
  end
end
