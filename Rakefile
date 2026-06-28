require "bundler/gem_tasks"

Rake::Task["release"].clear

desc "Build and publish the gem without Git operations"
task release: ["build", "release:rubygem_push"]
