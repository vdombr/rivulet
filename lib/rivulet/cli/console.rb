require 'rivulet'

module Rivulet
  module CLI
    module Commands
      class Console < Dry::CLI::Command
        desc 'Run console within rivulet environmet'

        def call(**)
          Rivulet.app.run_console
        end
      end
    end
  end
end
