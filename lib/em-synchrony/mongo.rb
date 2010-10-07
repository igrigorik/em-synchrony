require 'em-synchrony/em-thread'
require 'em-synchrony/em-tcpsocket'
require 'mongo/connection'

# monkey-patch Mongo to use em-synchrony's socket and thread classs
silence_warnings do
  class Mongo::Connection
    TCPSocket = ::EM::TCPSocket
    Mutex = ::EM::Synchrony::Thread::Mutex
    ConditionVariable = ::EM::Synchrony::Thread::ConditionVariable
  end
end
