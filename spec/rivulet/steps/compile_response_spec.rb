# frozen_string_literal: true

RSpec.describe Rivulet::Steps::CompileResponse do
  subject(:step) { described_class.new.call(input) }

  let(:format) { :json }
  let(:body) { nil }
  let(:status) { 200 }
  let(:response) { Rivulet::Response.new(status: status, format: format, body: body) }
  let(:route) { Rivulet::Routing::Route.new(path: '/test_path') }
  let(:sendfile_config) do
    double('SendfileConfig', enabled: false, variation: 'x-accel-redirect', mappings: [])
  end
  let(:app) do
    double('App', config: double('Config', sendfile: sendfile_config))
  end
  let(:input) do
    {
      route: route,
      response: response,
      resource: app
    }
  end

  describe '#call' do
    context 'when response has user-defined headers' do
      let(:format) { :json }
      let(:body) { { key: 'value' } }
      let(:response) do
        Rivulet::Response.new(status: status, format: format, body: body).tap do |r|
          r.headers['Content-Type'] = 'application/vnd.api+json'
          r.headers['X-Custom']     = 'custom-value'
        end
      end

      it { expect(step).to be_success }

      it 'overrides compiled Content-Type with user-defined value' do
        expect(step.value![:response][1]['Content-Type']).to eq('application/vnd.api+json')
      end

      it 'preserves user-defined headers not set by compile step' do
        expect(step.value![:response][1]['X-Custom']).to eq('custom-value')
      end

      it 'still includes compiled headers not overridden by user' do
        expect(step.value![:response][1]['Content-Length']).to eq(Oj.dump(body, mode: :json).bytesize.to_s)
      end
    end

    context 'when format is json' do
      let(:format) { :json }

      context 'with a hash body' do
        let(:body) do
          {
            user: {
              id: 1,
              roles: %w[admin user]
            }
          }
        end

        it { expect(step).to be_success }

        it 'returns serialized json body' do
          expect(step.value![:response][2].join).to eq Oj.dump(body, mode: :json)
        end

        it 'sets expected headers' do
          expect(step.value![:response][1]).to include(
            'Content-Type'   => 'application/json',
            'Content-Length' => Oj.dump(body, mode: :json).bytesize.to_s
          )
        end
      end

      context 'with an array body' do
        let(:body) { [{ id: 1, name: 'John Doe' }, { id: 2, name: 'Jane Doe' }] }

        it { expect(step).to be_success }

        it 'returns serialized json body' do
          expect(step.value![:response][2].join).to eq Oj.dump(body, mode: :json)
        end

        it 'sets expected headers' do
          expect(step.value![:response][1]).to include(
            'Content-Type'   => 'application/json',
            'Content-Length' => Oj.dump(body, mode: :json).bytesize.to_s
          )
        end
      end

      context 'with a nil body' do
        let(:body) { nil }

        it { expect(step).to be_success }

        it 'returns serialized null' do
          expect(step.value![:response][2].join).to eq Oj.dump(nil, mode: :json)
        end

        it 'sets expected headers' do
          expect(step.value![:response][1]).to include(
            'Content-Type'   => 'application/json',
            'Content-Length' => '4'
          )
        end
      end
    end

    context 'when format is text' do
      let(:format) { :text }

      context 'with a string body' do
        let(:body) { 'Hello, World!' }

        it { expect(step).to be_success }

        it 'returns the serialized body' do
          expect(step.value![:response][2].join).to eq 'Hello, World!'
        end

        it 'sets expected headers' do
          expect(step.value![:response][1]).to include(
            'Content-Type'   => 'text/plain; charset=utf-8',
            'Content-Length' => '13'
          )
        end
      end

      context 'with an integer body' do
        let(:body) { 42 }

        it { expect(step).to be_success }

        it 'returns the body as string' do
          expect(step.value![:response][2].join).to eq '42'
        end

        it 'sets expected headers' do
          expect(step.value![:response][1]).to include(
            'Content-Type'   => 'text/plain; charset=utf-8',
            'Content-Length' => '2'
          )
        end
      end
    end

    context 'when format is file' do
      let(:format) { :file }
      let(:file) do
        f = Tempfile.new(['report', '.xlsx'])
        f.write('content')
        f.rewind
        f
      end
      let(:body) { file.path }

      around do |ex|
        ex.run
        file.close
        file.unlink
      end

      context 'with a string path' do
        it { expect(step).to be_success }

        it 'returns the file content as body' do
          expect(step.value![:response][2].join).to eq 'content'
        end

        it 'sets MIME type from extension' do
          expect(step.value![:response][1]['Content-Type']).not_to eq('application/octet-stream')
        end

        it 'does not set Content-Disposition header' do
          expect(step.value![:response][1]).not_to have_key('Content-Disposition')
        end
      end

      context 'with a hash body containing only path' do
        let(:body) { { path: file.path } }

        it { expect(step).to be_success }

        it 'returns the file content as body' do
          expect(step.value![:response][2].join).to eq 'content'
        end

        it 'sets Content-Disposition with default inline disposition and basename' do
          expect(step.value![:response][1]['Content-Disposition'])
            .to eq("inline; filename=\"#{File.basename(file.path)}\"")
        end
      end

      context 'with a hash body containing path and filename' do
        let(:body) { { path: file.path, filename: 'report-2026.xlsx' } }

        it { expect(step).to be_success }

        it 'sets Content-Disposition with default inline disposition and specified filename' do
          expect(step.value![:response][1]['Content-Disposition'])
            .to eq('inline; filename="report-2026.xlsx"')
        end
      end

      context 'with a hash body containing explicit attachment disposition' do
        let(:body) { { path: file.path, filename: 'report-2026.xlsx', disposition: 'attachment' } }

        it { expect(step).to be_success }

        it 'sets Content-Disposition with attachment disposition' do
          expect(step.value![:response][1]['Content-Disposition'])
            .to eq('attachment; filename="report-2026.xlsx"')
        end
      end

      context 'with a hash body containing mime_type override' do
        let(:body) { { path: file.path, mime_type: 'image/png' } }

        it { expect(step).to be_success }

        it 'uses the provided mime_type for Content-Type' do
          expect(step.value![:response][1]['Content-Type']).to eq('image/png')
        end
      end

      context 'with a filename extension determining MIME type' do
        let(:file) do
          f = Tempfile.new(['report', '.custom'])
          f.write('x')
          f.rewind
          f
        end
        let(:body) { { path: file.path, filename: 'archive.zip' } }

        it { expect(step).to be_success }

        it 'uses the provided filename extension to determine MIME type' do
          expect(step.value![:response][1]['Content-Type']).to eq('application/zip')
        end
      end

      context 'with an unknown file extension' do
        let(:file) do
          f = Tempfile.new(['dump', '.mydata'])
          f.write('x')
          f.rewind
          f
        end
        let(:body) { file.path }

        it { expect(step).to be_success }

        it 'falls back to application/octet-stream' do
          expect(step.value![:response][1]['Content-Type']).to eq('application/octet-stream')
        end
      end

      context 'when the file does not exist' do
        let(:body) { '/nonexistent/path/to/file.txt' }

        it { expect(step).to be_failure }

        it 'returns file_not_found failure with descriptive message' do
          expect(step.failure).to eq [:file_not_found, 'Cannot read file: /nonexistent/path/to/file.txt']
        end
      end

      context 'when sendfile is enabled' do
        let(:mappings) { [] }
        let(:sendfile_config) do
          double('SendfileConfig', enabled: true, variation: variation, mappings: mappings)
        end
        let(:variation) { 'x-accel-redirect' }

        context 'with no mappings' do
          it { expect(step).to be_success }

          it 'sets X-Accel-Redirect to the raw path' do
            expect(step.value![:response][1]['x-accel-redirect']).to eq(file.path)
          end

          it 'sets Content-Length to 0' do
            expect(step.value![:response][1]['Content-Length']).to eq('0')
          end

          it 'returns empty body' do
            expect(step.value![:response][2]).to eq([])
          end
        end

        context 'with path mapping' do
          let(:mappings) { [['/var/www/', '/files/']] }
          let(:body) { '/var/www/reports/file.xlsx' }

          it { expect(step).to be_success }

          it 'sets X-Accel-Redirect to the mapped URI' do
            expect(step.value![:response][1]['x-accel-redirect']).to eq('/files/reports/file.xlsx')
          end

          it 'sets Content-Length to 0' do
            expect(step.value![:response][1]['Content-Length']).to eq('0')
          end
        end

        context 'with hash body containing filename' do
          let(:body) { { path: file.path, filename: 'report.xlsx' } }

          it { expect(step).to be_success }

          it 'sets Content-Disposition for nginx to pass through' do
            expect(step.value![:response][1]['Content-Disposition']).to eq('inline; filename="report.xlsx"')
          end

          it 'sets Content-Type from filename extension' do
            expect(step.value![:response][1]['Content-Type']).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
          end

          it 'sets X-Accel-Redirect to the path' do
            expect(step.value![:response][1]['x-accel-redirect']).to eq(file.path)
          end
        end

        context 'with custom variation' do
          let(:variation) { 'x-sendfile' }
          let(:body) { '/var/www/file.txt' }

          it { expect(step).to be_success }

          it 'sets X-Sendfile header instead of X-Accel-Redirect' do
            expect(step.value![:response][1]['x-sendfile']).to eq('/var/www/file.txt')
            expect(step.value![:response][1]).not_to have_key('x-accel-redirect')
          end
        end

        context 'when file does not exist' do
          let(:body) { '/nonexistent/path/to/file.txt' }

          it { expect(step).to be_success }

          it 'sets X-Accel-Redirect regardless of file existence' do
            expect(step.value![:response][1]['x-accel-redirect']).to eq('/nonexistent/path/to/file.txt')
          end
        end
      end
    end

    context 'when format is stream' do
      let(:format) { :stream }
      let(:body) { StringIO.new("a\nb\n") }

      it { expect(step).to be_success }

      it 'wraps the body in a Protocol::HTTP::Body::Stream' do
        expect(step.value![:response][2]).to be_a(Protocol::HTTP::Body::Stream)
      end

      it 'wraps the original IO as the stream input' do
        expect(step.value![:response][2].input).to eq(body)
      end
    end

    context 'when format is as_is' do
      let(:format) { :as_is }
      let(:body) { ['raw', 'body'] }

      it { expect(step).to be_success }

      it 'passes the body through unchanged' do
        expect(step.value![:response][2]).to eq(body)
      end
    end
  end
end
