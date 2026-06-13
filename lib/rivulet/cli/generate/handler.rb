require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Handler < Dry::CLI::Command
          desc "Generate a handler"
          argument :name, required: true, desc: "Handler name (e.g. Users or users)"

          option :create, type: :boolean, aliases: ['-c'], desc: 'Add "create" operation'
          option :read,   type: :boolean, aliases: ['-r'], desc: 'Add "show" operation'
          option :update, type: :boolean, aliases: ['-u'], desc: 'Add "update" operation'
          option :delete, type: :boolean, aliases: ['-d'], desc: 'Add "delete" operation'
          option :list,   type: :boolean, aliases: ['-l'], desc: 'Add "index" operation'

          SUBDIRS = %w[operations steps].freeze

          def call(name:, **options)
            dir_name    = underscore(name)
            module_name = camelize(dir_name)
            base        = "app/handlers/#{dir_name}"

            SUBDIRS.each { |d| create_dir "#{base}/#{d}" }
            write "#{base}/handler.rb", handler_template(module_name)
            create_container(base, module_name) unless File.exist?("#{base}/container.rb")
            register_handler(dir_name, module_name)

            if options[:create]
              Operation.new.call(name: "#{name}.create")
            end

            if options[:read]
              Operation.new.call(name: "#{name}.show")
            end

            if options[:update]
              Operation.new.call(name: "#{name}.update")
            end

            if options[:delete]
              Operation.new.call(name: "#{name}.delete")
            end

            if options[:list]
              Operation.new.call(name: "#{name}.index")
            end
          end

          private

          def underscore(str)
            str
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase
          end

          def camelize(str)
            str.split('_').map(&:capitalize).join
          end

          def create_container(base, module_name)
            write "#{base}/container.rb", container_template(module_name)
          end

          def create_dir(path)
            FileUtils.mkdir_p(path)
            puts "  create  #{path}/"
          end

          def write(path, content)
            File.write(path, content)
            puts "  create  #{path}"
          end

          def handler_template(module_name)
            <<~RUBY
              module Handlers
                module #{module_name}
                  class Handler
                    NAMESPACE = 'operations'

                    def method_missing(name, input = {}, options = {}, &block)
                      key = [NAMESPACE, name].join('.')
                      super unless Container.key?(key)

                      Container[key].call(input, **options, &block)
                    end

                    def respond_to_missing?(name, include_private = false)
                      key = [NAMESPACE, name].join('.')
                      Container.key?(key) || super
                    end
                  end
                end
              end
            RUBY
          end

          def container_template(module_name)
            <<~RUBY
              module Handlers
                module #{module_name}
                  class Container
                    extend Dry::Core::Container::Mixin
                    import Handlers::Shared::Namespace

                    namespace('operations') do
                    end

                    namespace('steps') do
                    end
                  end
                end
              end
            RUBY
          end

          def register_handler(dir_name, module_name)
            handlers_file = 'app/handlers.rb'
            return unless File.exist?(handlers_file)

            content      = File.read(handlers_file)
            registration = "  register('#{dir_name}') { Handlers::#{module_name}::Handler.new }\n"

            updated = content.sub(/^end\s*\z/, "#{registration}end\n")
            File.write(handlers_file, updated)
            puts "  update  #{handlers_file}"
          end
        end
      end
    end
  end
end
