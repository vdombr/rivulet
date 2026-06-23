# frozen_string_literal: true

RSpec.describe Rivulet::Steps::ValidateResponse do
  subject(:step) { described_class.new.call(input) }

  let(:format) { :json }
  let(:body) { nil }
  let(:status) { 200 }
  let(:response) { Rivulet::Response.new(status: status, format: format, body: body) }
  let(:route) { Rivulet::Routing::Route.new(path: '/test_path') }
  let(:input) do
    {
      route: route,
      response: response
    }
  end

  describe '#call' do
    context 'with valid response' do
      it { expect(step).to be_success }
    end

    context 'when response has invalid type' do
      let(:response) { "not a response" }

      it { expect(step).to be_failure }

      it 'returns wrong_response_type failure with descriptive message' do
        expect(step.failure).to eq [:wrong_response_type, "Invalid response type for /test_path"]
      end
    end

    context 'when response has status 204 or 304' do
      context 'with status 204 and nil body' do
        let(:body) { nil }
        let(:status) { 204 }

        it { expect(step).to be_success }
      end

      context 'with status 304 and nil body' do
        let(:body) { nil }
        let(:status) { 304 }

        it { expect(step).to be_success }
      end

      context 'with status 204 and non-nil body' do
        let(:body) { "unexpected content" }
        let(:status) { 204 }

        it { expect(step).to be_failure }

        it 'returns conflicting_response failure with descriptive message' do
          expect(step.failure).to eq [:conflicting_response, "Status 204 has body unexpected content"]
        end
      end

      context 'with status 304 and non-nil body' do
        let(:body) { "unexpected content" }
        let(:status) { 304 }

        it { expect(step).to be_failure }

        it 'returns conflicting_response failure with descriptive message' do
          expect(step.failure).to eq [:conflicting_response, "Status 304 has body unexpected content"]
        end
      end
    end

    context 'with stream format' do
      let(:format) { :stream }

      context 'when body is an IO-like object' do
        let(:body) { StringIO.new("data") }

        it { expect(step).to be_success }
      end

      context 'when body is not like io object' do
        let(:body) { "not an io" }

        it { expect(step).to be_failure }

        it 'returns wrong_response_type failure with descriptive message' do
          expect(step.failure).to eq [:wrong_response_type, "Response body is not supported for stream format"]
        end
      end
    end

    context 'with json format' do
      let(:format) { :json }
      let(:body) { { key: "value" } }

      it { expect(step).to be_success }
    end

    context 'with text format' do
      let(:format) { :text }
      let(:body) { "hello" }

      it { expect(step).to be_success }
    end

    context 'with file format' do
      let(:format) { :file }

      context 'when body is a string path' do
        let(:body) { "path/to/file" }

        it { expect(step).to be_success }
      end

      context 'when body is a hash' do
        let(:body) { { path: "path/to/file", filename: "report.xlsx" } }

        it { expect(step).to be_success }
      end

      context 'when body is a hash without :path' do
        let(:body) { { filename: "report.xlsx" } }

        it { expect(step).to be_failure }

        it 'returns wrong_response_type failure with descriptive message' do
          expect(step.failure).to eq [:wrong_response_type, "File body requires :path key"]
        end
      end

      context 'when body is an unsupported type' do
        let(:body) { 42 }

        it { expect(step).to be_failure }

        it 'returns wrong_response_type failure with descriptive message' do
          expect(step.failure).to eq [:wrong_response_type, "Response body is not supported for file format"]
        end
      end
    end

    context 'with as_is format' do
      let(:format) { :as_is }
      let(:body) { ["raw body"] }

      it { expect(step).to be_success }
    end

    context 'with unsupported format' do
      let(:format) { :xml }

      it { expect(step).to be_failure }

      it 'returns wrong_response_format failure with descriptive message' do
        expect(step.failure).to eq [:wrong_response_format, "Unsupported response format :xml"]
      end
    end
  end
end
