module Rivulet
  class Response
    attr_accessor :status, :headers, :body, :format

    def initialize(status: 200, headers: {}, body: [], format: :json)
      @status = status
      @headers = headers
      @body = body
      @format = format
    end
  end
end
