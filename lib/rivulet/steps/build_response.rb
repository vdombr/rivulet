module Rivulet
  module Steps
    class BuildResponse < Rivulet::Step
      NO_BODY_STATUSES = [204, 304].freeze

      def call(input)
        response = input[:response]

        unless response.is_a? Rivulet::Response
          return Failure[:wrong_reponse_type, "Invalid response type for #{input[:route].path}"]
        end

        if NO_BODY_STATUSES.include? response.status && !response.body.nil?
          return Failure[:conflicting_response, "Status #{response.status} has body #{response.body}"]
        end

        status = response.status
        format = response.format
        body, headers =
          case format
          when :json
            payload = Oj.dump(response.body, mode: :json)

            [
              Array(payload),
              {
                'Content-Type'   => 'application/json',
                'Content-Length' => payload.bytesize.to_s
              }
            ]
          when :text
            [
              Array(response.body),
              {
                'Content-Type'   => 'text/plain; charset=utf-8',
                'Content-Length' => response.body.bytesize.to_s
              }
            ]
          when :file
          when :stream, :as_is
            [response.body, {}]
          else
            [[], {}]
          end

        headers.merge!(response.headers)

        input[:response] = [status, headers, body]

        Success(input)
      end
    end
  end
end
