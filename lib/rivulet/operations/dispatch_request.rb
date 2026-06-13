module Rivulet
  module Operations
    class DispatchRequest < Rivulet::Operation
      include Import[
        build_context:    'steps.build_context',
        dispatch:         'steps.dispatch',
        build_response:   'steps.build_response'
      ]

      def call(input = {})
        result = step build_context.(input)
        result = step dispatch.(result)
        result = step build_response.(result)

        result
      end
    end
  end
end
