require 'irb'
require 'irb/completion'

module Rivulet
  module Steps
    class RunConsole < Rivulet::Step
      def call(input)
        app = input[:resource]

        IRB.setup(nil)

        IRB.conf[:USE_AUTOCOMPLETE] = false
        IRB.conf[:AP_NAME] = 'rivulet'

        # workspace = IRB::WorkSpace.new(binding)
        # irb = IRB::Irb.new(workspace)

        # IRB.conf[:MAIN_CONTEXT] = irb.context

        IRB::Irb.new.run(IRB.conf)

        Success(input)
      end
    end
  end
end
