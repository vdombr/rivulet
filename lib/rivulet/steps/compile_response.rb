module Rivulet
  module Steps
    class CompileResponse < Rivulet::Step
      def call(input)
        input => { resource:, response: }

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
            result = build_file_body(response.body, resource)
            return result if result in Failure
            result
          when :stream
            [Protocol::HTTP::Body::Stream.new(response.body), {}]
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

      def build_file_body(body, app)
        path = body.is_a?(Hash) ? body[:path] : body

        if app.config.sendfile.enabled
          build_sendfile_body(body, path, app.config.sendfile)
        else
          build_streaming_file_body(body, path)
        end
      end

      def build_streaming_file_body(body, path)
        file_body =
          begin
            Protocol::HTTP::Body::File.open(path)
          rescue Errno::ENOENT, Errno::EACCES
            return Failure[:file_not_found, "Cannot read file: #{path}"]
          end

        [file_body, file_headers(body, file_body.length)]
      end

      def build_sendfile_body(body, path, sendfile_config)
        uri     = map_sendfile_path(path, sendfile_config.mappings)
        headers = file_headers(body, 0)
        headers[sendfile_config.variation.downcase] = uri
        [[], headers]
      end

      def map_sendfile_path(path, mappings)
        return path if mappings.empty?

        mappings.each do |internal, external|
          mapped = path.sub(/\A#{Regexp.escape(internal)}/i, external)
          return mapped unless mapped == path
        end

        path
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
