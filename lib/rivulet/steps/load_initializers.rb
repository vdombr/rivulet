module Rivulet
  module Steps
    class LoadInitializers < Rivulet::Step
      def call(input)
        init_dir = Dir[File.expand_path('config/initializers/**/*.rb')]

        init_dir.each do |init_file|
          require init_file
        end

        Success(input)
      end
    end
  end
end
