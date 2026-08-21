module Rivulet
  class Container
    extend Dry::Core::Container::Mixin

    namespace('operations') do
      register('startup')          { Rivulet::Operations::Startup.new }
      register('dispatch_request') { Rivulet::Operations::DispatchRequest.new }
      register('migrate')          { Rivulet::Operations::Migrate.new }
      register('run_console')      { Rivulet::Operations::RunConsole.new }
      register('print_routes')     { Rivulet::Operations::PrintRoutes.new }
    end

    namespace('steps') do
      register('build_config')      { Rivulet::Steps::BuildConfig.new }
      register('build_context')     { Rivulet::Steps::BuildContext.new }
      register('validate_response') { Rivulet::Steps::ValidateResponse.new }
      register('compile_response')  { Rivulet::Steps::CompileResponse.new }
      register('dispatch')          { Rivulet::Steps::Dispatch.new }
      register('load_app')          { Rivulet::Steps::LoadApp.new }
      register('load_settings')     { Rivulet::Steps::LoadSettings.new }
      register('load_db')           { Rivulet::Steps::LoadDb.new }
      register('load_routes')       { Rivulet::Steps::LoadRoutes.new }
      register('load_initializers') { Rivulet::Steps::LoadInitializers.new }
      register('run_migrations')    { Rivulet::Steps::RunMigrations.new }
      register('run_console')       { Rivulet::Steps::RunConsole.new }
      register('print_routes')      { Rivulet::Steps::PrintRoutes.new }
    end
  end
end
