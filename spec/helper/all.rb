require 'spec/helper/core'
require 'lib/em-synchrony/mysql2'
require 'lib/em-synchrony/em-remcached'
require 'lib/em-synchrony/em-memcache'
require 'lib/em-synchrony/em-mongo'
require 'lib/em-synchrony/em-redis'
require 'lib/em-synchrony/em-hiredis'
require 'lib/em-synchrony/amqp'

require 'helper/tolerance_matcher'
require 'helper/stub-http-server'

def now(); Time.now.to_f; end

RSpec.configure do |config|
  config.include(Sander6::CustomMatchers)

  config.filter_run_excluding ci_skip: true if ENV['CI']
end
