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

  class Mongo::Pool
    TCPSocket = ::EventMachine::Synchrony::TCPSocket
    Mutex = ::EventMachine::Synchrony::Thread::Mutex
    ConditionVariable = ::EventMachine::Synchrony::Thread::ConditionVariable
  end

  class EventMachine::Synchrony::MongoTimeoutHandler
    def self.timeout(op_timeout, ex_class, &block)
      f = Fiber.current
      timer = EM::Timer.new(op_timeout) { f.resume(nil) }
      res = block.call
      timer.cancel
      res
    end
  end

  Mongo::TimeoutHandler = EventMachine::Synchrony::MongoTimeoutHandler
end