module Rivulet
  class Telemetry
    attr_reader :db_ms

    def initialize
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @root       = nil
      @stack      = []
      @db_ms      = 0.0
    end

    def start_recording(activity)
      node = Rivulet::Telemetry::Node.new(
        name: activity.class.name,
        started_at: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        children: []
      )

      if @stack.empty?
        @root = node
      else
        @stack.last[:children] << node
      end

      @stack << node
    end

    def stop_recording(activity)
      node = @stack.pop
      node.ended_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      node.duration_ms =
        ((node.ended_at - node.started_at) * 1000.0).round(3)
      node.self_ms =
        (node.duration_ms - node.children.sum(&:duration_ms)).round(3)
    end

    def record_db(ms)
      @db_ms = (@db_ms + ms).round(3)
    end

    def total_ms
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at) * 1000).round(3)
    end

    def flow
      @root
    end

    def print_flow(node = @root, offset = 0)
      entry = " " * 2 * offset
      entry += "#{node.name} (#{node.self_ms})"
      entry += " =>" if node.children.any?
      entry += "\n"

      node.children.each do |cnode|
        entry += print_flow(cnode, offset + 1)
      end

      entry
    end
  end
end
