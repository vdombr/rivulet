require 'zeitwerk'

module Rivulet
  module Steps
    class LoadApp < Rivulet::Step
      def call(input)
        app_dir = File.expand_path('app')
        return Success(input) unless Dir.exist?(app_dir)

        loader = Zeitwerk::Loader.new
        loader.push_dir(app_dir)
        loader.push_dir("#{app_dir}/models")
        loader.setup
        loader.eager_load

        Success(input)
      end
    end
  end
end
