# frozen_string_literal: true

RSpec.describe Rivulet::Steps::Dispatch do
  include Dry::Monads[:result]

  subject(:step) { described_class.new.call(input) }

  let(:callable) { double('Callable') }
  let(:route) { Rivulet::Routing::Route.new(callable: callable) }
  let(:params) { { id: '42' } }
  let(:context) { { headers: {}, cookies: {}, session: {} } }
  let(:input) { { route: route, params: params, context: context } }

  before { allow(callable).to receive(:call).and_return(callable_result) }

  describe '#call' do
    context 'when callable returns Success' do
      let(:response) { Rivulet::Response.new(status: 200, format: :json, body: { ok: true }) }
      let(:callable_result) { Success(response) }

      it { expect(step).to be_success }

      it 'unwraps the response from the Success value' do
        expect(step.value![:response]).to eq(response)
      end

      it 'passes only params and context to the callable' do
        step
        expect(callable).to have_received(:call).with(params: params, context: context)
      end
    end

    context 'when callable returns Failure' do
      let(:response) { Rivulet::Response.new(status: 422, format: :json, body: { error: 'validation_failed' }) }
      let(:callable_result) { Failure(response) }

      it { expect(step).to be_success }

      it 'unwraps the Response from the Failure result' do
        expect(step.value![:response]).to eq(response)
      end
    end
  end
end
