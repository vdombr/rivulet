module Rivulet
  module Steps
    class ValidateResponse < Rivulet::Step
      NO_BODY_STATUSES = [204, 304].freeze
      FORMAT_VALUES = %i[json text file stream as_is].freeze

      def call(input)
        input => { response:, route: }

        unless response.is_a? Rivulet::Response
          return Failure[:wrong_response_type, "Invalid response type for #{route.path}"]
        end

        if NO_BODY_STATUSES.include?(response.status) && !response.body.nil?
          return Failure[:conflicting_response, "Status #{response.status} has body #{response.body}"]
        end

        unless FORMAT_VALUES.include?(response.format)
          return Failure[:wrong_response_format, "Unsupported response format #{response.format.inspect}"]
        end

        if response.format == :stream && !io_like?(response.body)
          return Failure[:wrong_response_type, 'Response body is not supported for stream format']
        end

        if response.format == :file
          body = response.body
          return Failure[:wrong_response_type, "File body requires :path key"] if body.is_a?(Hash) && !body.key?(:path)
          return Failure[:wrong_response_type, "Response body is not supported for file format"] unless body.is_a?(String) || body.is_a?(Hash)
        end

        Success(input)
      end

      private

      def io_like?(obj)
        %i[gets each read rewind].all? { obj.respond_to?(_1) }
      end
    end
  end
end
