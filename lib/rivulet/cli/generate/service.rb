require 'dry/inflector'
require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Service < Dry::CLI::Command
          desc "Generate a service"
          argument :name, required: true, desc: "Service name (e.g. Users or users)"

          option :create, type: :boolean, aliases: ['-c'], desc: 'Add "create" operation'
          option :read,   type: :boolean, aliases: ['-r'], desc: 'Add "get" operation'
          option :update, type: :boolean, aliases: ['-u'], desc: 'Add "update" operation'
          option :delete, type: :boolean, aliases: ['-d'], desc: 'Add "delete" operation'
          option :list,   type: :boolean, aliases: ['-l'], desc: 'Add "list" operation'

          SUBDIRS = %w[contracts operations steps].freeze

          def call(name:, **options)
            dir_name      = underscore(name)
            module_name   = camelize(dir_name)
            base          = "app/services/#{dir_name}"
            singular_name = Dry::Inflector.new.singularize(name)

            SUBDIRS.each { |d| create_dir "#{base}/#{d}" }
            write "#{base}/service.rb", service_template(module_name)
            create_container(base, module_name) unless File.exist?("#{base}/container.rb")
            register_service(dir_name, module_name)

            if options[:create]
              Operation.new.call(name: "#{name}.create_#{singular_name}")
            end

            if options[:read]
              Operation.new.call(name: "#{name}.get_#{singular_name}")
            end

            if options[:update]
              Operation.new.call(name: "#{name}.update_#{singular_name}")
            end

            if options[:delete]
              Operation.new.call(name: "#{name}.delete_#{singular_name}")
            end

            if options[:list]
              Operation.new.call(name: "#{name}.list_#{name}")
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

          def create_dir(path)
            FileUtils.mkdir_p(path)
            puts "  create  #{path}/"
          end

          def create_container(base, module_name)
            write "#{base}/container.rb", container_template(module_name)
          end

          def write(path, content)
            File.write(path, content)
            puts "  create  #{path}"
          end

          def service_template(module_name)
            <<~RUBY
              module Services
                module #{module_name}
                  class Service
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
              module Services
                module #{module_name}
                  class Container
                    extend Dry::Core::Container::Mixin
                    import Services::Shared::Namespace

                    namespace('operations') do
                    end

                    namespace('steps') do
                    end

                    namespace('contracts') do
                    end

                    namespace('projections') do
                    end
                  end
                end
              end
            RUBY
          end

          def register_service(dir_name, module_name)
            services_file = 'app/services.rb'
            return unless File.exist?(services_file)

            content      = File.read(services_file)
            registration = "  register('#{dir_name}') { Services::#{module_name}::Service.new }\n"

            updated = content.sub(/^end\s*\z/, "#{registration}end\n")
            File.write(services_file, updated)
            puts "  update  #{services_file}"
          end
        end
      end
    end
  end
end
