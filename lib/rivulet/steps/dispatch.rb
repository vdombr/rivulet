module Rivulet
  module Steps
    class Dispatch < Rivulet::Step
      def call(input)
        result = input[:route].callable.call(input.slice(:params, :context))

        # We don't care if it's success or failure.
        # The result will be a response anyway.
        input[:response] = result.value_or(result.failure)

        Success(input)
      end
    end
  end
end
