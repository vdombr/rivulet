module Rivulet
  module Routing
    class Mapper
      include Enumerable

      def each(&block)
        @routes.each(&block)
      end

      def initialize(routes, prefix: '', scopes: [])
        @routes = routes
        @prefix = prefix
        @scopes = scopes
      end

      %i[get post put patch delete].each do |method|
        define_method(method) do |path, to:|
          handler_name = case to
                         when String then to
                         when Hash then "#{to[:to]}#{'#' + to[:action] if to[:action]}"
                         else nil
                         end

          route_path = join(@prefix, path.to_s)
          path_regex, param_names = compile_path(route_path)

          @routes << Route.new(
            http_method: method,
            path:        route_path,
            callable:    build_callable(to),
            scopes:      @scopes,
            handler_name: handler_name,
            path_regex:   path_regex,
            param_names:  param_names
          )
        end
      end

      def draw(&block)
        instance_eval(&block)
      end

      def scope(name, &block)
        Mapper.new(
          @routes,
          prefix: join(@prefix, name.to_s),
          scopes: @scopes + [name]
        ).instance_eval(&block)
      end

      def build_callable(to)
        case to
        when String
          handler, action = to.split('#')
        when Hash
          handler, action = to.values_at(:to, :action)
        else
          raise 'Cannot parse route handler'
        end

        ->(input) { ::Handlers[handler].send(action, input) }
      end

      private

      def join(*parts)
        '/' + parts.flat_map { |p| p.to_s.split('/') }.reject(&:empty?).join('/')
      end

      def compile_path(path)
        param_names = path.scan(/:([^\/]+)/).flatten.map(&:to_sym)
        regex = /\A#{Regexp.escape(path).gsub(/:[^\/]+/, '([^/]+)')}\z/

        [regex, param_names]
      end
    end
  end
end
