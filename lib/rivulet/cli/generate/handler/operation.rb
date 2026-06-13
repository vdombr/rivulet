require 'fileutils'

module Rivulet
  module CLI
    module Commands
      module Generate
        class Handler
          class Operation < Dry::CLI::Command
            desc "Generate an operation"
            argument :name, required: true, desc: "Operation name in handler.operation format (e.g. users.create)"

            def call(name:, **)
              handler_name, operation_name = name.split('.')
              handler_dir      = underscore(handler_name)
              operation_dir    = underscore(operation_name)
              handler_module   = camelize(handler_dir)
              operation_module = camelize(operation_dir)
              base             = "app/handlers/#{handler_dir}"

              write "#{base}/operations/#{operation_dir}.rb", operation_template(handler_module, operation_module)
              register_operation(base, handler_dir, handler_module, operation_dir, operation_module)
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

            def operation_template(handler_module, operation_module)
              <<~RUBY
                module Handlers
                  module #{handler_module}
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

            def register_operation(base, handler_dir, handler_module, operation_dir, operation_module)
              container_file        = "#{base}/container.rb"
              op_registration       = "        register('#{operation_dir}') { Handlers::#{handler_module}::Operations::#{operation_module}.new }\n"

              if File.exist?(container_file)
                content = File.read(container_file)
                content.sub!(/(      namespace\('operations'\) do\n)/, "\\1#{op_registration}")
                File.write(container_file, content)
                puts "  update  #{container_file}"
              else
                write container_file, container_template(handler_module, operation_dir, operation_module)
              end
            end
          end
        end
      end
    end
  end
end
