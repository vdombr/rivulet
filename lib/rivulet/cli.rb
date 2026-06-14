require 'dry/cli'
require_relative 'cli/new'
require_relative 'cli/console'
require_relative 'cli/routes'
require_relative 'cli/db/migrate'
require_relative 'cli/generate/operation'
require_relative 'cli/generate/handler'
require_relative 'cli/generate/handler/operation'
require_relative 'cli/generate/handler/step'
require_relative 'cli/generate/migration'
require_relative 'cli/generate/resource'
require_relative 'cli/generate/service'
require_relative 'cli/generate/service/operation'
require_relative 'cli/generate/service/step'
require_relative 'cli/generate/service/projection'

module Rivulet
  module CLI
    module Commands
      extend Dry::CLI::Registry

      register 'new', Commands::New
      register 'console', Commands::Console, aliases: ['c']
      register 'routes', Commands::Routes

      register 'generate', aliases: ['g'] do |prefix|
        prefix.register 'resource',           Commands::Generate::Resource
        prefix.register 'service',            Commands::Generate::Service
        prefix.register 'service operation',  Commands::Generate::Service::Operation
        prefix.register 'service step',       Commands::Generate::Service::Step
        prefix.register 'service projection', Commands::Generate::Service::Projection
        prefix.register 'handler',            Commands::Generate::Handler
        prefix.register 'handler operation',  Commands::Generate::Handler::Operation
        prefix.register 'handler step',       Commands::Generate::Handler::Step
        prefix.register 'migration',          Commands::Generate::Migration
      end

      register 'db' do |prefix|
        prefix.register 'migrate', Commands::DB::Migrate
      end
    end
  end
end
