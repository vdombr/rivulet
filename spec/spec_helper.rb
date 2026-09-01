# frozen_string_literal: true

require 'dry/monads'
require 'dry/auto_inject'
require 'dry/core/container'
require 'dry/logger'
require 'oj'
require 'protocol/http'
require 'protocol/http/body/file'
require 'protocol/http/body/stream'
require 'pry'
require 'rack'
require 'rack/mime'
require 'tempfile'

require 'stringio'

require_relative '../lib/rivulet/telemetry'
require_relative '../lib/rivulet/telemetry/node'
require_relative '../lib/rivulet/telemetry/timing_wrapper'
require_relative '../lib/rivulet/step'
require_relative '../lib/rivulet/container'
require_relative '../lib/rivulet/request'
require_relative '../lib/rivulet/response'
require_relative '../lib/rivulet/routing/route'
require_relative '../lib/rivulet/routing/mapper'
require_relative '../lib/rivulet/steps/validate_response'
require_relative '../lib/rivulet/steps/compile_response'
require_relative '../lib/rivulet/steps/build_context'
require_relative '../lib/rivulet/steps/dispatch'
require_relative '../lib/rivulet/steps/load_routes'
require_relative '../lib/rivulet/steps/load_initializers'
require_relative '../lib/rivulet/telemetry'
require_relative '../lib/rivulet/telemetry/sink'
require_relative '../lib/rivulet/telemetry/node'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end
