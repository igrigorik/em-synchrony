# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "em-synchrony"
  s.version     = "1.0.6"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ilya Grigorik"]
  s.email       = ["ilya@igvita.com"]
  s.homepage    = "http://github.com/igrigorik/em-synchrony"
  s.license     = "MIT"
  s.summary     = %q{Fiber aware EventMachine libraries}
  s.description = s.summary

  s.add_runtime_dependency("eventmachine", ">= 1.0.0.beta.1")

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
