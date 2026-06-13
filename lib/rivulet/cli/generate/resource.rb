require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Resource < Dry::CLI::Command
          desc "Generate a resource (handler + service)"
          argument :name, required: true, desc: "Resource name (e.g. Users or users)"

          option :create, type: :boolean, aliases: ['-c'], desc: 'Add operations to create resource'
          option :read,   type: :boolean, aliases: ['-r'], desc: 'Add operations to read resource'
          option :update, type: :boolean, aliases: ['-u'], desc: 'Add operations to update resource'
          option :delete, type: :boolean, aliases: ['-d'], desc: 'Add operations to delete resource'
          option :list,   type: :boolean, aliases: ['-l'], desc: 'Add operations to list resource'

          def call(name:, **options)
            Handler.new.call(name: name, **options)
            Service.new.call(name: name, **options)
          end
        end
      end
    end
  end
end
