require 'forwardable'
require 'dry/monads'
require 'dry/operation'
require 'dry/configurable'
require 'dry/auto_inject'
require 'dry/core/container'
require 'dry/logger'
require 'dry/validation'
require 'dry/transformer'
require 'oj'
require 'protocol/http'
require 'protocol/http/body/file'
require 'rack'
require 'rack/utils'
require 'sequel'

require_relative 'rivulet/version'
require_relative 'rivulet/telemetry'
require_relative 'rivulet/telemetry/node'
require_relative 'rivulet/telemetry/sequel_extension'
require_relative 'rivulet/telemetry/timing_wrapper'
require_relative 'rivulet/step'
require_relative 'rivulet/container'
require_relative 'rivulet/operation'
require_relative 'rivulet/request'
require_relative 'rivulet/response'
require_relative 'rivulet/projection'
require_relative 'rivulet/routing/route'
require_relative 'rivulet/routing/mapper'
require_relative 'rivulet/steps/build_config'
require_relative 'rivulet/steps/build_context'
require_relative 'rivulet/steps/validate_response'
require_relative 'rivulet/steps/compile_response'
require_relative 'rivulet/steps/dispatch'
require_relative 'rivulet/steps/load_app'
require_relative 'rivulet/steps/load_db'
require_relative 'rivulet/steps/load_routes'
require_relative 'rivulet/steps/load_settings'
require_relative 'rivulet/steps/print_routes'
require_relative 'rivulet/steps/run_migrations'
require_relative 'rivulet/steps/run_console'
require_relative 'rivulet/operations/startup'
require_relative 'rivulet/operations/dispatch_request'
require_relative 'rivulet/operations/migrate'
require_relative 'rivulet/operations/print_routes'
require_relative 'rivulet/operations/run_console'
require_relative 'rivulet/application'

module Rivulet
  extend SingleForwardable

  def_delegators :app, :config, :configure, :routes, :logger

  def self.app
    return @app if @app

    @app = Application.new
    @app
  end

  def self.plugin(as: 'rivulet')
    Dry::Core::Container::Namespace.new(as) do
    end
  end
end
