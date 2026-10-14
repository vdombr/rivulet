module Rivulet
  module Steps
    class FreezeSettings < Rivulet::Step
      def call(input)
        app = input[:resource]
        app.config.finalize!

        Success(input)
      end
    end
  end
end
