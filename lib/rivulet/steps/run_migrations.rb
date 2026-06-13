module Rivulet
  module Steps
    class RunMigrations < Rivulet::Step
      TABLE = :schema_migrations

      def call(input)
        db = input[:resource].db
        return Failure("Database not configured") unless db

        ensure_table(db)
        migrations = pending(db)

        if migrations.empty?
          puts "  up to date"
        else
          migrations.each do |path|
            version = File.basename(path, '.sql')
            db.transaction do
              db.run(File.read(path))
              db[TABLE].insert(version: version)
            end
            puts "  applied  #{File.basename(path)}"
          end
        end

        Success(input)
      end

      private

      def ensure_table(db)
        db.create_table?(TABLE) do
          String :version, null: false
          primary_key [:version]
        end
      end

      def pending(db)
        applied = db[TABLE].select_map(:version).to_set
        all_files.reject { |f| applied.include?(File.basename(f, '.sql')) }
      end

      def all_files
        dir = File.expand_path('db/migrations')
        return [] unless Dir.exist?(dir)
        Dir[File.join(dir, '*.sql')].sort
      end
    end
  end
end
