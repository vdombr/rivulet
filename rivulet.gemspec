require_relative 'lib/rivulet/version'

Gem::Specification.new do |spec|
  spec.name    = 'rivulet'
  spec.version = Rivulet::VERSION
  spec.summary = 'A small Rack web framework built on dry-rb'
  spec.authors = ['Vladimir Dombrovskiy <vold@fastmail.com>']

  spec.files         = Dir['lib/**/*.rb'] + Dir['bin/*']
  spec.executables   = ['rivulet']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.1'

  spec.add_dependency 'dry-auto_inject'
  spec.add_dependency 'dry-cli'
  spec.add_dependency 'dry-inflector'
  spec.add_dependency 'dry-logger'
  spec.add_dependency 'dry-configurable'
  spec.add_dependency 'dry-core'
  spec.add_dependency 'dry-monads'
  spec.add_dependency 'dry-operation'
  spec.add_dependency 'dry-validation'
  spec.add_dependency 'dry-transformer'
  spec.add_dependency 'oj'
  spec.add_dependency 'rack'
  spec.add_dependency 'zeitwerk'
  spec.add_dependency 'sequel'

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'sqlite3'
end
