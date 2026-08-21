# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe Rivulet::Steps::LoadInitializers do
  subject(:result) { step.call({}) }

  let(:step) { described_class.new }

  after do
    FileUtils.rm_rf(Dir.glob('config/initializers/*'))
  end

  it 'loads Ruby initializers recursively' do
    write_initializer('first.rb', "class FirstObject; end")
    write_initializer('nested/object.rb', "class NestedObject; end")
    write_initializer('ignored.txt', "class Ignored; end")

    expect(result).to be_success
    expect(defined?(FirstObject)).to be_truthy
    expect(defined?(NestedObject)).to be_truthy
    expect(defined?(Ignored)).to be_falsey
  end

  it 'propagates errors raised by an initializer' do
    write_initializer('broken.rb', "raise 'initializer failed'")

    expect { result }.to raise_error(RuntimeError, 'initializer failed')
  end

  def write_initializer(name, body)
    path = File.join('config/initializers', name)
    FileUtils.mkdir_p(File.dirname(path))
    content = body
    File.write(path, content)
  end
end
