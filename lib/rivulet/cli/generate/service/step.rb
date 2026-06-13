require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Service
          class Step < Dry::CLI::Command
            desc "Generate a step"
            argument :name, required: true, desc: "Step name in service.step format (e.g. users.create)"

            def call(name:, **)
              service_name, step_name = name.split('.')
              service_dir    = underscore(service_name)
              step_dir       = underscore(step_name)
              service_module = camelize(service_dir)
              step_class     = camelize(step_dir)
              base           = "app/services/#{service_dir}"

              write "#{base}/steps/#{step_dir}.rb", step_template(service_module, step_class)
              register_step(base, service_module, step_dir, step_class)
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

            def step_template(service_module, step_class)
              <<~RUBY
                module Services
                  module #{service_module}
                    module Steps
                      class #{step_class} < Rivulet::Step
                        def call(input)
                        end
                      end
                    end
                  end
                end
              RUBY
            end

            def register_step(base, service_module, step_name, step_class)
              container_file       = "#{base}/container.rb"
              step_registration      = "        register('#{step_name}') { Services::#{service_module}::Steps::#{step_class}.new }\n"

              if File.exist?(container_file)
                content = File.read(container_file)
                content.sub!(/(      namespace\('steps'\) do\n)/, "\\1#{step_registration}")
                File.write(container_file, content)
                puts "  update  #{container_file}"
              else
                write container_file, container_template(service_module, step_name, step_class)
              end
            end

            def container_template(service_module, step_name, step_class)
              <<~RUBY
                module Services
                  module #{service_module}
                    class Container
                      extend Dry::Core::Container::Mixin

                      namespace('steps') do
                        register('#{step_name}') { Services::#{service_module}::Steps::#{step_class}.new }
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
