require 'rivulet'

module Rivulet
  module CLI
    module Commands
      module DB
        class Migrate < Dry::CLI::Command
          desc "Run pending database migrations"

          def call(**)
            Rivulet.app.migrate!
          end
        end
      end
    end
  end
end
