require 'rubygems'
require 'spec'
require 'pp'
require 'em-http'

require 'lib/em-fiber'
require 'tolerance_matcher'
require 'stub-http-server'

Spec::Runner.configure do |config|
  config.include(Sander6::CustomMatchers)
end