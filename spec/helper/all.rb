require 'rubygems'
require 'rspec'
require 'pp'

require 'lib/em-synchrony'
require 'lib/em-synchrony/em-http'
require 'lib/em-synchrony/mysql2'
require 'lib/em-synchrony/em-remcached'
require 'lib/em-synchrony/em-memcache'
require 'lib/em-synchrony/em-mongo'
require 'lib/em-synchrony/em-redis'
require 'lib/em-synchrony/em-hiredis'

require 'helper/tolerance_matcher'
require 'helper/stub-http-server'

def now(); Time.now.to_f; end

def silence_warnings()
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end

RSpec.configure do |config|
  config.include(Sander6::CustomMatchers)
end
