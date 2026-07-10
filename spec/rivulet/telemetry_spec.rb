RSpec.describe Rivulet::Telemetry do
  let(:sink_calls) { [] }
  let(:sink) do
    Class.new do
      attr_reader :calls

      def initialize(calls)
        @calls = calls
      end

      def on_start(node, parent)
        calls << [:on_start, node.name, parent&.name]
      end

      def on_stop(node)
        calls << [:on_stop, node.name, node.duration_ms]
      end

      def on_db(ms)
        calls << [:on_db, ms]
      end

      def on_root(node, total_ms)
        calls << [:on_root, node.name, total_ms]
      end
    end.new(sink_calls)
  end

  class FakeActivity
  end

  it 'delegates start_recording to the sink' do
    telemetry = Rivulet::Telemetry.new(sink: sink)
    activity = FakeActivity.new
    telemetry.start_recording(activity)

    expect(sink_calls).to include([:on_start, 'FakeActivity', nil])
  end

  it 'delegates stop_recording to the sink with duration' do
    telemetry = Rivulet::Telemetry.new(sink: sink)
    activity = FakeActivity.new
    telemetry.start_recording(activity)
    sleep 0.01
    telemetry.stop_recording(activity)

    expect(sink_calls).to include(
      [:on_stop, 'FakeActivity', kind_of(Float)]
    )
  end

  it 'delegates record_db to the sink' do
    telemetry = Rivulet::Telemetry.new(sink: sink)
    telemetry.record_db(12.5)

    expect(sink_calls).to include([:on_db, 12.5])
  end

  it 'calls on_root with the root node when finish is called' do
    telemetry = Rivulet::Telemetry.new(sink: sink)
    activity = FakeActivity.new
    telemetry.start_recording(activity)
    telemetry.stop_recording(activity)
    telemetry.finish

    expect(sink_calls).to include(
      [:on_root, 'FakeActivity', kind_of(Float)]
    )
  end

  it 'passes parent node name to sink on_start for nested nodes' do
    telemetry = Rivulet::Telemetry.new(sink: sink)
    parent_activity = FakeActivity.new
    child_activity = Class.new(FakeActivity).new
    telemetry.start_recording(parent_activity)
    telemetry.start_recording(child_activity)

    expect(sink_calls).to include(
      [:on_start, child_activity.class.name, 'FakeActivity']
    )
  end

  it 'still builds the in-memory tree alongside the sink' do
    telemetry = Rivulet::Telemetry.new(sink: sink)
    parent = FakeActivity.new
    child = Class.new(FakeActivity).new
    telemetry.start_recording(parent)
    telemetry.start_recording(child)
    telemetry.stop_recording(child)
    telemetry.stop_recording(parent)

    expect(telemetry.flow.name).to eq('FakeActivity')
    expect(telemetry.flow.children.first.name).to eq(child.class.name)
  end
end
