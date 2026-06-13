module Rivulet
  module Steps
    class LoadRoutes < Rivulet::Step
      def call(input)
        routes_file = File.expand_path('config/routes.rb')
        return Failure("Routes file not found: #{routes_file}") unless File.exist?(routes_file)

        load(routes_file)

        Success(input)
      end
    end
  end
end
