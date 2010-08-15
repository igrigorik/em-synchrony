require 'em-synchrony/em-thread'
require 'em-synchrony/em-tcpsocket'
require 'mongo/connection'
require 'mongoid'

# monkey-patch Mongo to use em-synchrony's socket and thread classs
silence_warnings do
  class Mongo::Connection
    TCPSocket = ::EM::TCPSocket
    Mutex = ::EM::Synchrony::Thread::Mutex
    ConditionVariable = ::EM::Synchrony::Thread::ConditionVariable
  end
end

# disable mongoid connection initializer
if defined? Rails
  module Rails
    module Mongoid
      class Railtie < Rails::Railtie
        initializers.delete_if { |i| i.name == 'verify that mongoid is configured' }
      end
    end
  end
end
