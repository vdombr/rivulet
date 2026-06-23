module Rivulet
  module Steps
    class LoadRoutes < Rivulet::Step
      def call(input)
        routes_file = File.expand_path('config/routes.rb')
        return Failure("Routes file not found: #{routes_file}") unless File.exist?(routes_file)

        load(routes_file)

        duplicates = duplicate_routes(input[:resource].routes)
        return Failure(duplicate_message(duplicates)) unless duplicates.empty?

        Success(input)
      end

      private

      def duplicate_routes(routes)
        routes.group_by { |r| [r.http_method, r.path] }.select { |_, v| v.size > 1 }
      end

      def duplicate_message(duplicates)
        list = duplicates.keys.map { |m, p| "#{m.to_s.upcase} #{p}" }.join(', ')
        "Duplicate routes: #{list}"
      end
    end
  end
end
