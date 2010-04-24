require 'rubygems'
require 'spec'
require 'pp'

require 'lib/em-synchrony'
require 'lib/em-synchrony/em-http'
require 'lib/em-synchrony/em-mysqlplus'
require 'lib/em-synchrony/em-remcached'

require 'helper/tolerance_matcher'
require 'helper/stub-http-server'

def now(); Time.now.to_f; end

Spec::Runner.configure do |config|
  config.include(Sander6::CustomMatchers)
end