module Rivulet
  module Steps
    class Dispatch < Rivulet::Step
      def call(input)
        input => { route:, params:, context: }

        result = route.callable.call(params: params, context: context)

        # We don't care if it's success or failure.
        # The result will be a response anyway.
        input[:response] = result.value_or(result.failure)

        Success(input)
      end
    end
  end
end
