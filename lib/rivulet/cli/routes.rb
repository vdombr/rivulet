require 'rivulet'

module Rivulet
  module CLI
    module Commands
      class Routes < Dry::CLI::Command
        desc 'Show routes'

        def call(**)
          Rivulet.app.print_routes
        end
      end
    end
  end
end
