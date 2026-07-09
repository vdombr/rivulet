require 'sequel'
require_relative '../telemetry/sequel_extension'

# Load globally BEFORE connecting — fiber_concurrency is a Sequel-wide extension,
# not a per-database extension. It replaces the default connection pool with a
# fiber-aware one that gives each fiber its own connection.
Sequel.extension(:fiber_concurrency)

module Rivulet
  module Steps
    class LoadDb < Rivulet::Step
      def call(input)
        app = input[:resource]
        db_config = app.config.database
        return Failure("Rivulet.config.database.dsn is required") if db_config&.dsn.to_s.empty?

        pool = db_config.pool&.to_h || {}
        db   = Sequel.connect(db_config.dsn, **pool, logger: app.logger, sql_log_level: :debug)
        db.extension(:rivulet_telemetry)
        app.db = db

        Sequel::Model.db = db
        Sequel::Model.require_valid_table = false

        Success(input)
      end
    end
  end
end
