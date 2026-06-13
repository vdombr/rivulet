module Rivulet
  class Request
    attr_reader :http_method, :path, :content_type, :body, :session, :env

    def initialize(env)
      @http_method  = env['REQUEST_METHOD'].downcase.to_sym
      @path         = env['PATH_INFO']
      @content_type = env['CONTENT_TYPE']
      @body         = env['rack.input']
      @session      = env['rack.session']
      @env          = env
    end

    def cookies
      Rack::Utils.parse_cookies(env)
    end
  end
end
