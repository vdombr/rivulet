module Rivulet
  module Operations
    class Startup < Rivulet::Operation
      include Import[
        build_config:      'steps.build_config',
        load_settings:     'steps.load_settings',
        load_app:          'steps.load_app',
        load_db:           'steps.load_db',
        load_routes:       'steps.load_routes',
        load_initializers: 'steps.load_initializers'
      ]

      def call(input = {})
        result = step build_config.(input)
        result = step load_settings.(result)
        result = step load_db.(result)
        result = step load_app.(result)
        result = step load_routes.(result)
        result = step load_initializers.(result)

        result
      end
    end
  end
end
