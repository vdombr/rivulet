require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Service
          class Operation < Dry::CLI::Command
            desc "Generate an operation"
            argument :name, required: true, desc: "Operation name in service.operation format (e.g. users.create)"

            def call(name:, **)
              service_name, operation_name = name.split('.')
              service_dir      = underscore(service_name)
              operation_dir    = underscore(operation_name)
              service_module   = camelize(service_dir)
              operation_module = camelize(operation_dir)
              base             = "app/services/#{service_dir}"

              mkdir "#{base}/projections"
              write "#{base}/operations/#{operation_dir}.rb", operation_template(service_module, operation_module)
              write "#{base}/contracts/#{operation_dir}.rb",  contract_template(service_module, operation_module)
              register_operation(base, service_dir, service_module, operation_dir, operation_module)
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

            def mkdir(path)
              Dir.mkdir(path) unless Dir.exist?(path)
            end

            def write(path, content)
              File.write(path, content)
              puts "  create  #{path}"
            end

            def operation_template(service_module, operation_module)
              <<~RUBY
                module Services
                  module #{service_module}
                    module Operations
                      class #{operation_module} < Rivulet::Operation
                        def call(input = {})
                        end
                      end
                    end
                  end
                end
              RUBY
            end

            def contract_template(service_module, operation_module)
              <<~RUBY
                module Services
                  module #{service_module}
                    module Contracts
                      class #{operation_module} < ApplicationContract
                        params do
                        end
                      end
                    end
                  end
                end
              RUBY
            end

            def register_operation(base, service_dir, service_module, operation_dir, operation_module)
              container_file       = "#{base}/container.rb"
              op_registration      = "        register('#{operation_dir}') { Services::#{service_module}::Operations::#{operation_module}.new }\n"
              contract_registration = "        register('#{operation_dir}') { Services::#{service_module}::Contracts::#{operation_module}.new }\n"

              if File.exist?(container_file)
                content = File.read(container_file)
                content.sub!(/(      namespace\('operations'\) do\n)/, "\\1#{op_registration}")
                content.sub!(/(      namespace\('contracts'\) do\n)/, "\\1#{contract_registration}")
                File.write(container_file, content)
                puts "  update  #{container_file}"
              else
                write container_file, container_template(service_module, operation_dir, operation_module)
              end
            end

            def container_template(service_module, operation_dir, operation_module)
              <<~RUBY
                module Services
                  module #{service_module}
                    class Container
                      extend Dry::Core::Container::Mixin

                      namespace('operations') do
                        register('#{operation_dir}') { Services::#{service_module}::Operations::#{operation_module}.new }
                      end

                      namespace('contracts') do
                        register('#{operation_dir}') { Services::#{service_module}::Contracts::#{operation_module}.new }
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
