require 'fileutils'

module Rivulet
  module CLI
    module Commands
      class New < Dry::CLI::Command
        desc "Create a new Rivulet application"
        argument :name, required: true, desc: "Application name"
        option :with_db, values: %w[postgres sqlite mysql], desc: "Database adapter (omit for no database)"

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
          config/initializers
          db/migrations
        ].freeze

        def call(name:, with_db: nil, **)
          name = normalize_name(name)

          DIRS.each { |d| create_dir "#{name}/#{d}" }

          write name, 'Gemfile',                    gemfile(with_db)
          write name, 'config.ru',                 config_ru
          write name, 'config/application.rb',     application_config(name, with_db)
          write name, 'config/routes.rb',          routes_config
          write name, 'falcon.rb',                   falcon_config
          write name, 'Dockerfile',                  dockerfile(with_db)
          write name, 'docker-compose.yml',          docker_compose(name, with_db)
          write name, 'app/handlers.rb', handlers_container
          write name, 'app/handlers/shared/container.rb', handlers_shared_container
          write name, 'app/handlers/shared/namespace.rb', handlers_shared_namespace
          write name, 'app/services.rb', services_container
          write name, 'app/services/shared/container.rb', services_shared_container
          write name, 'app/services/shared/namespace.rb', services_shared_namespace
          write name, 'app/application_contract.rb', application_contract_template
          copy name, 'AGENTS.md', File.expand_path('../../../docs/AGENTS.md', __dir__)

          puts "\nDone! Next steps:\n  cd #{name}\n  docker compose up"
        rescue ArgumentError => e
          puts "ERROR: #{e.message}"
          exit false
        end

        private

        def normalize_name(name)
          normalized = name.to_s
                           # "HTTPServer" -> "HTTP_Server": split an acronym from the word that follows
                           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                           # "myApp" -> "my_App": split a camelCase boundary
                           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                           # "my app 2" -> "my_app_2": collapse spaces, dashes, dots, etc. into "_"
                           .gsub(/[^0-9a-zA-Z]+/, '_')
                           .downcase
                           # "  My App  " -> "my_app": drop leading/trailing "_"
                           .gsub(/\A_+|_+\z/, '')

          raise ArgumentError, "invalid application name #{name}" if normalized.empty?

          normalized
        end

        def create_dir(path)
          FileUtils.mkdir_p(path)
          puts "  create  #{path}/"
        end

        def write(root, relative_path, content)
          File.write(File.join(root, relative_path), content)
          puts "  create  #{relative_path}"
        end

        def copy(root, relative_path, source_path)
          FileUtils.copy_file(source_path, File.join(root, relative_path))
          puts "  create  #{relative_path}"
        end

        def gemfile(db)
          adapter = case db
                    when 'postgres' then "gem 'pg'"
                    when 'sqlite'   then "gem 'sqlite3'"
                    when 'mysql'    then "gem 'mysql2'"
                    end

          <<~RUBY
            source 'https://rubygems.org'

            gem 'rivulet-rb'
            gem 'falcon'
            #{adapter}
          RUBY
        end

        def config_ru
          <<~RUBY
            require 'rivulet'

            run Rivulet.app.startup
          RUBY
        end

        def application_config(name, db)
          dsn_default = case db
                        when 'postgres' then "postgres://rivulet:rivulet@db:5432/#{name}_development"
                        when 'sqlite'   then "sqlite://db/#{name}.sqlite3"
                        when 'mysql'    then "mysql2://rivulet:rivulet@db:3306/#{name}_development"
                        end

          dsn_line = if dsn_default
                       "config.database.dsn = ENV.fetch('DATABASE_URL', '#{dsn_default}')"
                     else
                       "# config.database.dsn = ENV.fetch('DATABASE_URL', 'postgres://rivulet:rivulet@db:5432/#{name}_development')"
                     end

          <<~RUBY
            Rivulet.configure do |config|
              config.app.name = :#{name}

              #{dsn_line}

              # config.sendfile.enabled   = true
              # config.sendfile.variation = 'x-accel-redirect'
              # config.sendfile.mappings   = [['/var/www/', '/files/']]

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

        def dockerfile(db)
          apk = case db
                when 'postgres' then "RUN apk add --no-cache postgresql-dev libpq\n\n"
                when 'sqlite'   then "RUN apk add --no-cache sqlite-dev\n\n"
                when 'mysql'    then "RUN apk add --no-cache mariadb-dev\n\n"
                end

          <<~DOCKERFILE
            FROM mrvold/rivulet:latest
            #{apk}WORKDIR /app
            COPY Gemfile ./
            RUN bundle install

            EXPOSE 9292

            ENTRYPOINT []
            CMD ["bundle", "exec", "falcon", "serve", "-n", "1", "-b", "http://0.0.0.0:9292"]
          DOCKERFILE
        end

        def docker_compose(name, db)
          case db
          when 'postgres' then docker_compose_postgres(name)
          when 'mysql'    then docker_compose_mysql(name)
          else                 docker_compose_simple
          end
        end

        def docker_compose_simple
          <<~YAML
            services:
              app:
                build: .
                ports:
                  - "9292:9292"
                volumes:
                  - ./:/app
          YAML
        end

        def docker_compose_postgres(name)
          <<~YAML
            services:
              app:
                build: .
                ports:
                  - "9292:9292"
                environment:
                  DATABASE_URL: postgres://rivulet:rivulet@db:5432/#{name}_development
                volumes:
                  - ./:/app
                depends_on:
                  db:
                    condition: service_healthy

              db:
                image: postgres:17-alpine
                environment:
                  POSTGRES_USER: rivulet
                  POSTGRES_PASSWORD: rivulet
                  POSTGRES_DB: #{name}_development
                ports:
                  - "5432:5432"
                volumes:
                  - db:/var/lib/postgresql/data
                healthcheck:
                  test: ["CMD-SHELL", "pg_isready -U rivulet -d #{name}_development"]
                  interval: 5s
                  timeout: 3s
                  retries: 5

            volumes:
              db:
          YAML
        end

        def docker_compose_mysql(name)
          <<~YAML
            services:
              app:
                build: .
                ports:
                  - "9292:9292"
                environment:
                  DATABASE_URL: mysql2://rivulet:rivulet@db:3306/#{name}_development
                volumes:
                  - ./:/app
                depends_on:
                  db:
                    condition: service_healthy

              db:
                image: mysql:8
                environment:
                  MYSQL_ROOT_PASSWORD: root
                  MYSQL_USER: rivulet
                  MYSQL_PASSWORD: rivulet
                  MYSQL_DATABASE: #{name}_development
                ports:
                  - "3306:3306"
                volumes:
                  - db:/var/lib/mysql
                healthcheck:
                  test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -u rivulet -privulet"]
                  interval: 5s
                  timeout: 3s
                  retries: 5

            volumes:
              db:
          YAML
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
