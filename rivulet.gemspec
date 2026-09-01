require_relative 'lib/rivulet/version'

Gem::Specification.new do |spec|
  spec.name    = 'rivulet-rb'
  spec.version = Rivulet::VERSION
  spec.summary = 'A small Rack web framework built on dry-rb, falcon and forced layering architecture'
  spec.authors = ['Vladimir Dombrovskiy <vold@fastmail.com>']
  spec.license = 'Apache-2.0'

  spec.files         = Dir['lib/**/*.rb'] + Dir['bin/*'] + Dir['docs/*.md']
  spec.executables   = ['rivulet']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.3'

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
  spec.add_dependency 'protocol-http'
  spec.add_dependency 'rack'
  spec.add_dependency 'zeitwerk'
  spec.add_dependency 'sequel'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'sqlite3'
end
