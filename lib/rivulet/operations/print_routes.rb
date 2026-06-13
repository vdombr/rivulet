module Rivulet
  module Operations
    class PrintRoutes < Rivulet::Operation
      include Import[
        load_routes: 'steps.load_routes',
        print_routes: 'steps.print_routes'
      ]

      def call(input = {})
        result = step load_routes.(input)
        result = step print_routes.(result)

        result
      end
    end
  end
end
