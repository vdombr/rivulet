module Rivulet
  class Request
    attr_reader :http_method, :path, :content_type, :query_string, :body, :session, :env

    def initialize(env)
      @http_method  = env['REQUEST_METHOD'].downcase.to_sym
      @path         = env['PATH_INFO']
      @content_type = env['CONTENT_TYPE']
      @query_string = env['QUERY_STRING']
      @body         = env['rack.input']
      @session      = env['rack.session']
      @env          = env
    end

    def cookies
      Rack::Utils.parse_cookies(env)
    end

    def query_params
      Rack::Utils
      .parse_nested_query(query_string)
      .then { |params| deep_symbolize_keys(params) }
    end

    def body_params
      return {} unless content_type&.include?('application/json')
      raw = body.read
      return {} if raw.nil? || raw.empty?
      Oj.load(raw, symbolize_names: true)
    rescue Oj::ParseError
      {}
    end

    private

    def deep_symbolize_keys(hash)
      hash.each_with_object({}) do |(key, val), result|
        val = deep_symbolize_keys(val) if val.is_a? Hash
        result[key.to_sym] = val
      end
    end
  end
end
