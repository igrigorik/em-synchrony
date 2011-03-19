require 'bundler'
require 'rspec/core/rake_task'

Bundler.setup
Bundler::GemHelper.install_tasks

desc "Run all RSpec tests"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec