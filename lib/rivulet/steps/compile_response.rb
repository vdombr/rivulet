module Rivulet
  module Steps
    class CompileResponse < Rivulet::Step
      def call(input)
        response = input[:response]

        status = response.status
        format = response.format

        body, headers =
          case format
          when :json
            payload = Oj.dump(response.body, mode: :json)

            [
              Protocol::HTTP::Body::Buffered.wrap(payload),
              {
                'Content-Type'   => 'application/json',
                'Content-Length' => payload.bytesize.to_s
              }
            ]
          when :text
            payload = response.body.to_s

            [
              Protocol::HTTP::Body::Buffered.wrap(payload),
              {
                'Content-Type'   => 'text/plain; charset=utf-8',
                'Content-Length' => payload.bytesize.to_s
              }
            ]
          when :file
            result = build_file_body(response.body)
            return result if result.respond_to?(:failure?)
            result
          when :stream
            [response.body, {}]
          when :as_is
            [response.body, {}]
          else
            [[], {}]
          end

        headers.merge!(response.headers)

        input[:response] = [status, headers, body]

        Success(input)
      end

      private

      def build_file_body(body)
        path = body.is_a?(Hash) ? body[:path] : body
        file_body =
          begin
            Protocol::HTTP::Body::File.open(path)
          rescue Errno::ENOENT, Errno::EACCES
            return Failure[:file_not_found, "Cannot read file: #{path}"]
          end

        [file_body, file_headers(body, file_body.length)]
      end

      def file_headers(body, length)
        if body.is_a?(Hash)
          path        = body[:path]
          filename    = body.fetch(:filename) { File.basename(path) }
          disposition = body.fetch(:disposition, 'inline')
          mime_type   = body.fetch(:mime_type) { Rack::Mime.mime_type(File.extname(filename)) }

          {
            'Content-Type'        => mime_type,
            'Content-Length'      => length.to_s,
            'Content-Disposition' => "#{disposition}; filename=\"#{filename}\""
          }
        else
          {
            'Content-Type'   => Rack::Mime.mime_type(File.extname(body)),
            'Content-Length' => length.to_s
          }
        end
      end
    end
  end
end
