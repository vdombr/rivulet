module Rivulet
  class Operation < Dry::Operation
    def self.container_class_path
      self
        .name
        .split('::')
        .then { |path| path[0...path.index('Operations')] }
        .push('Container')
        .inject(Object) { |mod, name| mod.const_get(name) }
    end

    def self.inherited(subclass)
      super

      subclass.prepend(Rivulet::Telemetry::TimingWrapper)
      subclass.const_set(
        :Import, Dry::AutoInject(subclass.container_class_path)
      )
    end
  end
end
