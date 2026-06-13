require "io/console"

module Rivulet
  module Steps
    class PrintRoutes < Rivulet::Step
      HEADERS = ['HTTP Verb', 'Path', 'Handler#action']
      GAP = 2

      def call(input)
        routes = input[:resource].routes

        widths = calculate_widths(routes)

        print_row(HEADERS, widths)
        puts "" # Spacer after header

        routes.each do |route|
          print_route(route, widths)
        end

        Success(input)
      end

      private

      def terminal_width
        IO.console.winsize[1]
      rescue
        80
      end

      def calculate_widths(routes)
        cols = HEADERS.size
        route_methods = [:http_method, :path, :callable]

        widths = Array.new(cols, 0)

        cols.times do |i|
          widths[i] = [
            HEADERS[i].length,
            *routes.map { |r| r.send(route_methods[i]).to_s.length }
          ].max
        end

        total_width_needed = widths.sum + GAP * (cols - 1)

        return widths if total_width_needed <= terminal_width

        # If too wide, shrink the last column to fit, prioritizing wrapping there.
        fixed_width = widths[0..-2].sum + GAP * (cols - 2)
        available_for_last = terminal_width - fixed_width - GAP

        widths[-1] = [available_for_last, 20].max

        # Final fallback to ensure total doesn't exceed terminal width
        while (widths.sum + GAP * (cols - 1)) > terminal_width && widths[-1] > 5
          widths[-
1] -= 1
        end

        widths
      end

      def print_route(route, widths)
        handler_display = route.handler_name || route.callable.inspect
        row_data = [route.http_method, route.path, handler_display]
        print_row(row_data, widths)
      end

      def print_row(cells, widths)
        wrapped_cells = cells.each_with_index.map do |cell, i|
          wrap(cell.to_s, widths[i])
        end

        num_lines = wrapped_cells.map(&:size).max

        num_lines.times do |line_idx|
          line_parts = wrapped_cells.each_with_index.map do |lines, col_idx|
            text = lines[line_idx] || ""
            text.ljust(widths[col_idx])
          end

          puts line_parts.join(" " * GAP)
        end
      end

      def wrap(text, width)
        return [] if text.empty?

        tokens = text.split(/(\s+)/)
        lines = []
        current_line = ""

        tokens.each do |token|
          if (current_line + token).length <= width
            current_line += token
          else
            if token.strip.empty?
              lines << current_line.rstrip
              current_line = ""
            elsif token.length > width
              parts = token.scan(/.{1,#{width}}/)
              parts.each_with_index do |part, idx|
                if idx == parts.size - 1
                  current_line += part
                else
                  lines << (current_line + part).rstrip
                  current_line = ""
                end
              end
            else
              lines << current_line.rstrip
              current_line = token
            end
          end
        end

        lines << current_line.rstrip unless current_line.empty?
        lines.reject(&:empty?)
      end
    end
  end
end
