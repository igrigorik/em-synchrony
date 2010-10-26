require 'rubygems'
require 'bundler'
Bundler.setup

require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

begin
  require "jeweler"
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "em-synchrony"
    gemspec.summary = "Fiber aware EventMachine libraries"
    gemspec.description = gemspec.summary
    gemspec.email = "ilya@igvita.com"
    gemspec.homepage = "http://github.com/igrigorik/em-synchrony"
    gemspec.authors = ["Ilya Grigorik"]
    gemspec.required_ruby_version = ">= 1.9"
    gemspec.add_dependency("eventmachine", ">= 0.12.9")
    gemspec.rubyforge_project = "em-synchrony"
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available: gem install jeweler"
end
