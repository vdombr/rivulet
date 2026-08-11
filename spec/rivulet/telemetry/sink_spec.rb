# frozen_string_literal: true

RSpec.describe Rivulet::Telemetry::Sink::Null do
  let(:sink) { described_class.new }
  let(:node) do
    Rivulet::Telemetry::Node.new(
      name: 'TestNode',
      started_at: 0.0,
      ended_at: 0.1,
      duration_ms: 100.0,
      self_ms: 80.0,
      children: []
    )
  end

  it 'is a no-op for on_start' do
    expect { sink.on_start(node, nil) }.not_to raise_error
  end

  it 'is a no-op for on_stop' do
    expect { sink.on_stop(node) }.not_to raise_error
  end

  it 'is a no-op for on_db' do
    expect { sink.on_db(42.0) }.not_to raise_error
  end

  it 'is a no-op for on_root' do
    expect { sink.on_root(node, 200.0) }.not_to raise_error
  end
end
