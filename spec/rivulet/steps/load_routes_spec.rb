# frozen_string_literal: true

RSpec.describe Rivulet::Steps::LoadRoutes do
  subject(:step) { instance.call(input) }

  let(:instance) { described_class.new }
  let(:routes) { Rivulet::Routing::Mapper.new([]) }
  let(:resource) { double('Resource', routes: routes) }
  let(:input) { { resource: resource } }

  before do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?)
      .with(File.expand_path('config/routes.rb'))
      .and_return(file_exists)
    allow(instance).to receive(:load).and_return(nil)
  end

  let(:file_exists) { true }

  describe '#call' do
    context 'when all routes are unique' do
      before do
        routes.draw do
          get  '/users/:id', to: 'users#show'
          post '/users',     to: 'users#create'
        end
      end

      it { expect(step).to be_success }
    end

    context 'when routes file is not found' do
      let(:file_exists) { false }

      it { expect(step).to be_failure }

      it 'returns a not-found failure with the file path' do
        expect(step.failure).to eq("Routes file not found: #{File.expand_path('config/routes.rb')}")
      end
    end

    context 'when a single route is duplicated' do
      before do
        routes.draw do
          get '/users/:id', to: 'users#show'
          get '/users/:id', to: 'users#show'
        end
      end

      it { expect(step).to be_failure }

      it 'returns a failure message listing the duplicated route' do
        expect(step.failure).to include('GET /users/:id')
      end
    end

    context 'when multiple routes are duplicated' do
      before do
        routes.draw do
          get  '/users/:id',   to: 'users#show'
          get  '/users/:id',   to: 'users#show'
          post '/orders/:id',  to: 'orders#create'
          post '/orders/:id',  to: 'orders#create'
        end
      end

      it { expect(step).to be_failure }

      it 'lists all duplicated routes in the message' do
        message = step.failure
        expect(message).to include('GET /users/:id')
        expect(message).to include('POST /orders/:id')
      end
    end

    context 'when the same path is used with different HTTP methods' do
      before do
        routes.draw do
          get  '/users/:id', to: 'users#show'
          post '/users/:id', to: 'users#create'
        end
      end

      it { expect(step).to be_success }
    end
  end
end
