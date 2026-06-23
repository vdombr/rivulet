require 'fileutils'

module Rivulet
  module CLI
    module Commands
      class New < Dry::CLI::Command
        desc "Create a new Rivulet application"
        argument :name, required: true, desc: "Application name"

        DIRS = %w[
          app/handlers
          app/handlers/shared
          app/handlers/shared/steps
          app/handlers/shared/utils
          app/services
          app/services/shared
          app/services/shared/steps
          app/services/shared/utils
          app/models
          config
          db/migrations
        ].freeze

        def call(name:, **)
          DIRS.each { |d| create_dir "#{name}/#{d}" }

          write name, 'Gemfile',                    gemfile
          write name, 'config.ru',                 config_ru
          write name, 'config/application.rb',     application_config(name)
          write name, 'config/routes.rb',          routes_config
          write name, 'falcon.rb',                   falcon_config
          write name, 'app/handlers.rb', handlers_container
          write name, 'app/handlers/shared/container.rb', handlers_shared_container
          write name, 'app/handlers/shared/namespace.rb', handlers_shared_namespace
          write name, 'app/services.rb', services_container
          write name, 'app/services/shared/container.rb', services_shared_container
          write name, 'app/services/shared/namespace.rb', services_shared_namespace
          write name, 'app/application_contract.rb', application_contract_template

          puts "\nDone! Next steps:\n  cd #{name}\n  bundle install\n  bundle exec falcon host falcon.rb"
        end

        private

        def create_dir(path)
          FileUtils.mkdir_p(path)
          puts "  create  #{path}/"
        end

        def write(root, relative_path, content)
          File.write(File.join(root, relative_path), content)
          puts "  create  #{relative_path}"
        end

        def gemfile
          <<~RUBY
            source 'https://rubygems.org'

            gem 'rivulet'
            gem 'falcon'
          RUBY
        end

        def config_ru
          <<~RUBY
            require 'rivulet'

            run Rivulet.app.startup
          RUBY
        end

        def application_config(name)
          <<~RUBY
            Rivulet.configure do |config|
              # config.database.dsn = ENV.fetch('DATABASE_URL', 'sqlite://db/#{name}.sqlite3')

              # config.sendfile.enabled   = true
              # config.sendfile.variation = 'x-accel-redirect'
              # config.sendfile.mappings   = [['/var/www/', '/files/']]

              config.logger.name  = :#{name}
              config.logger.level = :info
            end
          RUBY
        end

        def falcon_config
          <<~RUBY
            require 'falcon/environment/rack'
            require 'falcon/environment/server'

            service "app" do
              include Falcon::Environment::Server
              include Falcon::Environment::Rackup
            end
          RUBY
        end

        def routes_config
          <<~RUBY
            # get :posts, to: 'posts#index'

            Rivulet.routes.draw do
            end
          RUBY
        end

        def handlers_container
          <<~RUBY
            module Handlers
              extend Dry::Core::Container::Mixin
            end
          RUBY
        end

        def handlers_shared_container
          <<~RUBY
            module Handlers
              module Shared
                class Container
                  extend Dry::Core::Container::Mixin
                  import Namespace
                end
              end
            end
          RUBY
        end

        def handlers_shared_namespace
          <<~RUBY
            module Handlers
              module Shared
                Namespace = Dry::Core::Container::Namespace.new('shared') do
                  namespace('steps') do
                  end

                  namespace('utils') do
                  end
                end
              end
            end
          RUBY
        end

        def services_container
          <<~RUBY
            module Services
              extend Dry::Core::Container::Mixin
            end
          RUBY
        end

        def services_shared_container
          <<~RUBY
            module Services
              module Shared
                class Container
                  extend Dry::Core::Container::Mixin
                  import Namespace
                end
              end
            end
          RUBY
        end

        def services_shared_namespace
          <<~RUBY
            module Services
              module Shared
                Namespace = Dry::Core::Container::Namespace.new('shared') do
                  namespace('steps') do
                  end

                  namespace('utils') do
                  end
                end
              end
            end
          RUBY
        end

        def application_contract_template
          <<~RUBY
            class ApplicationContract < Dry::Validation::Contract
            end
          RUBY
        end
      end
    end
  end
end
