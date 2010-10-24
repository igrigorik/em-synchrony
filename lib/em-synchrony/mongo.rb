begin
  require "mongo/connection"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install mongo"
end

# monkey-patch Mongo to use em-synchrony's socket and thread classs
silence_warnings do
  class Mongo::Connection
    TCPSocket = ::EventMachine::Synchrony::TCPSocket
    Mutex = ::EventMachine::Synchrony::Thread::Mutex
    ConditionVariable = ::EventMachine::Synchrony::Thread::ConditionVariable
  end
end
