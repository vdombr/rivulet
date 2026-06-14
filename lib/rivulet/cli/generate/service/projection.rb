require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Service
          class Projection < Dry::CLI::Command
            desc "Generate a projection"
            argument :name, required: true, desc: "Step name in service.projection format (e.g. users.common)"

            def call(name:, **)
              service_name, step_name = name.split('.')
              service_dir      = underscore(service_name)
              projection_dir   = underscore(step_name)
              service_module   = camelize(service_dir)
              projection_class = camelize(projection_dir)
              base             = "app/services/#{service_dir}"

              write "#{base}/projections/#{projection_dir}.rb", projection_template(service_module, projection_class)
              register_projection(base, service_module, projection_dir, projection_class)
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

            def write(path, content)
              File.write(path, content)
              puts "  create  #{path}"
            end

            def projection_template(service_module, projection_class)
              <<~RUBY
                module Services
                  module #{service_module}
                    module Projections
                      class #{projection_class} < Rivulet::Projection
                      end
                    end
                  end
                end
              RUBY
            end

            def register_projection(base, service_module, projection_name, projection_class)
              container_file          = "#{base}/container.rb"
              projection_registration = "        register('#{projection_name}') { Services::#{service_module}::Projections::#{projection_class}.new }\n"

              if File.exist?(container_file)
                content = File.read(container_file)
                content.sub!(/(      namespace\('projections'\) do\n)/, "\\1#{projection_registration}")
                File.write(container_file, content)
                puts "  update  #{container_file}"
              else
                write container_file, container_template(service_module, projection_name, projection_class)
              end
            end

            def container_template(service_module, projection_name, projection_class)
              <<~RUBY
                module Services
                  module #{service_module}
                    class Container
                      extend Dry::Core::Container::Mixin

                      namespace('projections') do
                        register('#{projection_name}') { Services::#{service_module}::Projections::#{projection_class}.new }
                      end
                    end
                  end
                end
              RUBY
            end
          end
        end
      end
    end
  end
end
