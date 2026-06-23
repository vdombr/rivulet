# frozen_string_literal: true

RSpec.describe Rivulet::Steps::BuildContext do
  subject(:step) { described_class.new.call(input) }

  let(:log_output) { StringIO.new }
  let(:logger) { Dry.Logger(:test, stream: log_output) }
  let(:routes) { Rivulet::Routing::Mapper.new([]) }
  let(:resource) { double('Resource', routes: routes, logger: logger) }

  let(:path) { '/users/42' }
  let(:method) { 'GET' }
  let(:env_opts) { {} }
  let(:env) { Rack::MockRequest.env_for(path, env_opts.merge(method: method)) }
  let(:input) { { env: env, resource: resource } }

  before do
    routes.draw { get '/users/:id', to: 'users#show' }
  end

  describe '#call' do
    context 'when route matches' do
      it { expect(step).to be_success }

      it 'merges the matched route into input' do
        expect(step.value![:route].path).to eq('/users/:id')
      end
    end

    context 'when HTTP method does not match' do
      let(:method) { 'POST' }

      it { expect(step).to be_failure }

      it 'returns route_not_found failure' do
        expect(step.failure).to eq([:route_not_found])
      end
    end

    context 'when path does not match' do
      let(:path) { '/posts/42' }

      it { expect(step).to be_failure }

      it 'returns route_not_found failure' do
        expect(step.failure).to eq([:route_not_found])
      end
    end

    context 'with path params' do
      it 'extracts path params from the URL' do
        expect(step.value![:params][:id]).to eq('42')
      end

      context 'when body has a param with the same key as a path param' do
        let(:env_opts) do
          { input: '{"id":999}', 'CONTENT_TYPE' => 'application/json' }
        end

        it 'path param wins over body param' do
          expect(step.value![:params][:id]).to eq('42')
        end
      end
    end

    context 'with JSON body' do
      let(:env_opts) do
        { input: '{"name":"Joe","age":30}', 'CONTENT_TYPE' => 'application/json' }
      end

      it { expect(step).to be_success }

      it 'parses and merges body params' do
        expect(step.value![:params]).to include(name: 'Joe', age: 30)
      end
    end

    context 'with empty JSON body' do
      let(:env_opts) do
        { input: '', 'CONTENT_TYPE' => 'application/json' }
      end

      it { expect(step).to be_success }

      it 'returns empty body params' do
        expect(step.value![:params]).to eq(id: '42')
      end
    end

    context 'with invalid JSON body' do
      let(:env_opts) do
        { input: '{invalid json', 'CONTENT_TYPE' => 'application/json' }
      end

      it { expect(step).to be_success }

      it 'returns empty body params' do
        expect(step.value![:params]).to eq(id: '42')
      end
    end

    context 'with non-JSON content type' do
      let(:env_opts) do
        { input: '{"name":"Joe"}', 'CONTENT_TYPE' => 'text/plain' }
      end

      it { expect(step).to be_success }

      it 'does not parse the body' do
        expect(step.value![:params]).to eq(id: '42')
      end
    end

    context 'without content type' do
      it { expect(step).to be_success }

      it 'does not parse the body' do
        expect(step.value![:params]).to eq(id: '42')
      end
    end

    context 'with header extraction' do
      let(:env_opts) do
        {
          'HTTP_X_CUSTOM' => 'value',
          'HTTP_X_API_KEY' => 'secret',
          'CONTENT_TYPE' => 'application/json',
          input: '{}'
        }
      end

      it 'converts HTTP_X_CUSTOM to X-Custom' do
        expect(step.value![:context][:headers]['X-Custom']).to eq('value')
      end

      it 'capitalizes multi-word headers correctly' do
        expect(step.value![:context][:headers]['X-Api-Key']).to eq('secret')
      end

      it 'includes non-empty CONTENT_TYPE as Content-Type' do
        expect(step.value![:context][:headers]['Content-Type']).to eq('application/json')
      end

      it 'includes non-empty CONTENT_LENGTH as Content-Length' do
        expect(step.value![:context][:headers]['Content-Length']).to eq('2')
      end
    end

    context 'with empty CONTENT_TYPE and CONTENT_LENGTH' do
      let(:env_opts) do
        { 'CONTENT_TYPE' => '', 'CONTENT_LENGTH' => '' }
      end

      it { expect(step).to be_success }

      it 'omits empty Content-Type header' do
        expect(step.value![:context][:headers]).not_to have_key('Content-Type')
      end

      it 'omits empty Content-Length header' do
        expect(step.value![:context][:headers]).not_to have_key('Content-Length')
      end
    end

    context 'with cookies' do
      let(:env_opts) { { 'HTTP_COOKIE' => 'a=1; b=2' } }

      it { expect(step).to be_success }

      it 'parses cookies into context' do
        expect(step.value![:context][:cookies]).to eq('a' => '1', 'b' => '2')
      end
    end

    context 'with session' do
      let(:env_opts) { { 'rack.session' => { user_id: 7 } } }

      it { expect(step).to be_success }

      it 'passes session into context' do
        expect(step.value![:context][:session]).to eq(user_id: 7)
      end
    end

    context 'with logging' do
      it { expect(step).to be_success }

      it 'logs the request with upcased method, path, and params' do
        step
        expect(log_output.string).to match(/Request GET \/users\/42 .*\bid: "42"/)
      end
    end
  end
end
