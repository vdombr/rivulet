# frozen_string_literal: true

require 'dry/cli'
require 'tmpdir'
require 'fileutils'

require_relative '../../../lib/rivulet/cli/new'

RSpec.describe Rivulet::CLI::Commands::New do
  let(:app_name) { 'blog' }

  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        orig_stdout = $stdout
        $stdout = StringIO.new
        begin
          example.run
        ensure
          $stdout = orig_stdout
        end
      end
    end
  end

  context 'without params' do
    before { described_class.new.call(name: app_name) }

    it 'creates the expected directory structure' do
      expect(Dir.exist?("#{app_name}/app/handlers/shared/steps")).to be(true)
      expect(Dir.exist?("#{app_name}/app/services/shared/utils")).to be(true)
      expect(Dir.exist?("#{app_name}/db/migrations")).to be(true)
    end

    it 'writes a Gemfile without a database adapter' do
      gemfile = File.read("#{app_name}/Gemfile")
      expect(gemfile).to include("gem 'rivulet-rb'")
      expect(gemfile).to include("gem 'falcon'")
      expect(gemfile).not_to include("gem 'pg'")
      expect(gemfile).not_to include("gem 'sqlite3'")
      expect(gemfile).not_to include("gem 'mysql2'")
    end

    it 'comments out the database DSN' do
      config = File.read("#{app_name}/config/application.rb")
      expect(config).to include('# config.database.dsn =')
    end

    it 'writes a Dockerfile without database apk packages' do
      dockerfile = File.read("#{app_name}/Dockerfile")
      expect(dockerfile).to include('FROM mrvold/rivulet:latest')
      expect(dockerfile).not_to include('postgresql-dev')
      expect(dockerfile).not_to include('sqlite-dev')
      expect(dockerfile).not_to include('mariadb-dev')
    end

    it 'writes a simple docker-compose.yml without a db service' do
      compose = File.read("#{app_name}/docker-compose.yml")
      expect(compose).to include('build: .')
      expect(compose).not_to include('depends_on')
      expect(compose).not_to include('image: postgres')
      expect(compose).not_to include('image: mysql')
    end
  end

  context 'with --with-db' do
    let(:db) { raise 'override in nested context' }

    before { described_class.new.call(name: app_name, with_db: db) }

    shared_examples 'a database adapter' do
      it 'writes a Gemfile with rivulet-rb and no other adapters' do
        gemfile = File.read("#{app_name}/Gemfile")
        expect(gemfile).to include("gem 'rivulet-rb'")
        expect(gemfile).not_to include("gem 'pg'")       unless db == 'postgres'
        expect(gemfile).not_to include("gem 'sqlite3'")  unless db == 'sqlite'
        expect(gemfile).not_to include("gem 'mysql2'")   unless db == 'mysql'
      end

      it 'writes a Dockerfile without other adapters apk packages' do
        dockerfile = File.read("#{app_name}/Dockerfile")
        expect(dockerfile).not_to include('postgresql-dev') unless db == 'postgres'
        expect(dockerfile).not_to include('sqlite-dev')      unless db == 'sqlite'
        expect(dockerfile).not_to include('mariadb-dev')     unless db == 'mysql'
      end
    end

    context 'when db is postgres' do
      let(:db) { 'postgres' }
      include_examples 'a database adapter'

      it 'writes a Gemfile with the pg adapter' do
        expect(File.read("#{app_name}/Gemfile")).to include("gem 'pg'")
      end

      it 'configures the database DSN with a postgres default' do
        expect(File.read("#{app_name}/config/application.rb")).to include(
          "config.database.dsn = ENV.fetch('DATABASE_URL', 'postgres://rivulet:rivulet@db:5432/#{app_name}_development')"
        )
      end

      it 'writes a Dockerfile that builds on the base image and installs the pg adapter' do
        dockerfile = File.read("#{app_name}/Dockerfile")
        expect(dockerfile).to include('FROM mrvold/rivulet:latest')
        expect(dockerfile).to include('postgresql-dev libpq')
        expect(dockerfile).to include('COPY Gemfile ./')
        expect(dockerfile).to include('RUN bundle install')
        expect(dockerfile).to include('EXPOSE 9292')
        expect(dockerfile).to include('ENTRYPOINT []')
        expect(dockerfile).to include('CMD ["bundle", "exec", "falcon", "serve", "-n", "1", "-b", "http://0.0.0.0:9292"]')
      end

      it 'writes a docker-compose.yml that builds the app image and runs postgres' do
        compose = File.read("#{app_name}/docker-compose.yml")
        expect(compose).to include('build: .')
        expect(compose).to include('image: postgres:17-alpine')
        expect(compose).to include("POSTGRES_DB: #{app_name}_development")
        expect(compose).to include("DATABASE_URL: postgres://rivulet:rivulet@db:5432/#{app_name}_development")
        expect(compose).to include('condition: service_healthy')
      end
    end

    context 'when db is sqlite' do
      let(:db) { 'sqlite' }
      include_examples 'a database adapter'

      it 'writes a Gemfile with the sqlite3 adapter' do
        expect(File.read("#{app_name}/Gemfile")).to include("gem 'sqlite3'")
      end

      it 'configures the database DSN with a sqlite default' do
        expect(File.read("#{app_name}/config/application.rb")).to include(
          "config.database.dsn = ENV.fetch('DATABASE_URL', 'sqlite://db/#{app_name}.sqlite3')"
        )
      end

      it 'writes a Dockerfile that installs sqlite-dev' do
        expect(File.read("#{app_name}/Dockerfile")).to include('sqlite-dev')
      end

      it 'writes a simple docker-compose.yml without a db service' do
        compose = File.read("#{app_name}/docker-compose.yml")
        expect(compose).to include('build: .')
        expect(compose).not_to include('depends_on')
        expect(compose).not_to include('image: postgres')
        expect(compose).not_to include('image: mysql')
      end
    end

    context 'when db is mysql' do
      let(:db) { 'mysql' }
      include_examples 'a database adapter'

      it 'writes a Gemfile with the mysql2 adapter' do
        expect(File.read("#{app_name}/Gemfile")).to include("gem 'mysql2'")
      end

      it 'configures the database DSN with a mysql default' do
        expect(File.read("#{app_name}/config/application.rb")).to include(
          "config.database.dsn = ENV.fetch('DATABASE_URL', 'mysql2://rivulet:rivulet@db:3306/#{app_name}_development')"
        )
      end

      it 'writes a Dockerfile that installs mariadb-dev' do
        expect(File.read("#{app_name}/Dockerfile")).to include('mariadb-dev')
      end

      it 'writes a docker-compose.yml that builds the app image and runs mysql' do
        compose = File.read("#{app_name}/docker-compose.yml")
        expect(compose).to include('build: .')
        expect(compose).to include('image: mysql:8')
        expect(compose).to include("MYSQL_DATABASE: #{app_name}_development")
        expect(compose).to include("DATABASE_URL: mysql2://rivulet:rivulet@db:3306/#{app_name}_development")
        expect(compose).to include('condition: service_healthy')
      end
    end
  end
end
