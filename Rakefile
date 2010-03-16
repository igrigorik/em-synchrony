require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "em-synchrony"
    gemspec.summary = "Fiber aware EventMachine libraries"
    gemspec.description = gemspec.summary
    gemspec.email = "ilya@igvita.com"
    gemspec.homepage = "http://github.com/igrigorik/em-synchrony"
    gemspec.authors = ["Ilya Grigorik"]
    gemspec.required_ruby_version = ">= 1.9"
    gemspec.add_dependency('eventmachine', '>= 0.12.9')
    gemspec.rubyforge_project = "em-synchrony"
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
