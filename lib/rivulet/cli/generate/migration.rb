require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Migration < Dry::CLI::Command
          desc "Generate a migration"
          argument :name, required: true, desc: "Migration name (e.g. create_users)"

          def call(name:, **)
            FileUtils.mkdir_p('db/migrations')
            filename = "#{Time.now.strftime('%Y%m%d%H%M%S')}_#{underscore(name)}.sql"
            path     = File.join('db/migrations', filename)
            File.write(path, "")
            puts "  create  #{path}"
          end

          private

          def underscore(str)
            str
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase
          end
        end
      end
    end
  end
end
