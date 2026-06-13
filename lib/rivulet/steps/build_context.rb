module Rivulet
  module Steps
    class BuildContext < Rivulet::Step
      def call(input)
        request = Rivulet::Request.new(input[:env])
        routes = input[:resource].routes

        route, path_match = find_route(routes, request)
        return Failure[:route_not_found] unless route

        input.merge!(
          route: route,
          params: build_params(route, request, path_match),
          context: {
            headers: extract_headers(request),
            cookies: request.cookies,
            session: request.session
          }
        )

        input[:resource].logger.info(
          "Request #{request.http_method.upcase} #{request.path} #{input[:params]}"
        )

        Success(input)
      end

      private

      def build_params(route, request, path_match)
        path_params = extract_params(route, path_match)
        body_params = parse_body(request)
        body_params.merge(path_params)
      end

      def parse_body(request)
        return {} unless request.content_type&.include?('application/json')
        raw = request.body.read
        return {} if raw.nil? || raw.empty?
        Oj.load(raw, symbolize_names: true)
      rescue Oj::ParseError
        {}
      end

      def find_route(routes, request)
        request_method = request.http_method
        path_info = request.path

        routes.each do |route|
          next unless route.http_method == request_method

          path_match = route.path_regex.match(path_info)
          return [route, path_match] if path_match
        end

        [nil, nil]
      end

      def extract_headers(request)
        request.env.each_with_object({}) do |(key, value), headers|
          if key.start_with?('HTTP_')
            headers[key[5..].split('_').map(&:capitalize).join('-')] = value
          elsif (key == 'CONTENT_TYPE' || key == 'CONTENT_LENGTH') && !value.to_s.empty?
            headers[key.split('_').map(&:capitalize).join('-')] = value
          end
        end
      end

      def extract_params(route, path_match)
        route.param_names.zip(path_match.captures).to_h
      end
    end
  end
end
