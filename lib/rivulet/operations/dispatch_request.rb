module Rivulet
  module Operations
    class DispatchRequest < Rivulet::Operation
      include Import[
        build_context:      'steps.build_context',
        dispatch:           'steps.dispatch',
        validate_response:  'steps.validate_response',
        compile_response:   'steps.compile_response'
      ]

      def call(input = {})
        result = step build_context.(input)
        result = step dispatch.(result)
        result = step validate_response.(result)
        result = step compile_response.(result)

        result
      end
    end
  end
end
