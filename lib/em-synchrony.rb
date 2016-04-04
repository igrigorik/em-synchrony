$:.unshift(File.dirname(__FILE__) + '/../lib')

require "eventmachine"

begin
  require "fiber"
rescue LoadError => error
  raise error unless defined? Fiber
end

require "em-synchrony/core_ext"
require "em-synchrony/thread"
require "em-synchrony/em-multi"
require "em-synchrony/tcpsocket"
require "em-synchrony/connection_pool"
require "em-synchrony/keyboard"
require "em-synchrony/iterator"  if EventMachine::VERSION > '0.12.10'
require "em-synchrony/kernel"

module EventMachine

  # A convenience method for wrapping a given block within
  # a Ruby Fiber such that async operations can be transparently
  # paused and resumed based on IO scheduling.
  # It detects whether EM is running or not.
  def self.synchrony(blk=nil, tail=nil)
    # EM already running.
    if reactor_running?
      if block_given?
        Fiber.new { yield }.resume
      else
        Fiber.new { blk.call }.resume
      end
      tail && add_shutdown_hook(tail)

    # EM not running.
    else
      if block_given?
        run(nil, tail) { Fiber.new { yield }.resume }
      else
        run(Proc.new { Fiber.new { blk.call }.resume }, tail)
      end

    end
  end

  module Synchrony

    # sync is a close relative to inlineCallbacks from Twisted (Python)
    #
    # Synchrony.sync allows you to write sequential code while using asynchronous
    # or callback-based methods under the hood. Example:
    #
    # result = EM::Synchrony.sync EventMachine::HttpRequest.new(URL).get
    # p result.response
    #
    # As long as the asynchronous function returns a Deferrable object, which
    # has a "callback" and an "errback", the sync methond will automatically
    # yield and automatically resume your code (via Fibers) when the call
    # either succeeds or fails. You do not need to patch or modify the
    # Deferrable object, simply pass it to EM::Synchrony.sync
    #
    def self.sync(df)
      f = Fiber.current
      xback = proc do |*args|
        if f == Fiber.current
          return args.size == 1 ? args.first : args
        else
          f.resume(*args)
        end
      end

      df.callback(&xback)
      df.errback(&xback)

      Fiber.yield
    end


    # Fiber-aware sleep function using an EM timer
    #
    # Execution is stopped for specified amount of seconds
    # and then automatically resumed (just like regular sleep)
    # except without locking the reactor thread
    #
    def self.sleep(secs)
      fiber = Fiber.current
      EM::Timer.new(secs) { fiber.resume }
      Fiber.yield
    end

    # Fiber-aware EventMachine timer: wraps the passed in
    # block within a new fiber context such that you can
    # continue using synchrony methods
    #
    def self.add_timer(interval, &blk)
      EM::Timer.new(interval) do
        Fiber.new { blk.call }.resume
      end
    end

    # Fiber-aware EventMachine timer: wraps the passed in
    # block within a new fiber (new fiber on every invocation)
    # to allow you to continue using synchrony methods
    #
    def self.add_periodic_timer(interval, &blk)
      EM.add_periodic_timer(interval) do
        Fiber.new { blk.call }.resume
      end
    end

    # Fiber-aware EM.next_tick convenience function
    #
    def self.next_tick(&blk)
      EM.next_tick { Fiber.new { blk.call }.resume }
    end
    
    # Fiber-aware EM.defer 
    #            
    def self.defer op = nil, &blk
      fiber = Fiber.current
      EM.defer(op || blk, lambda{ |result| fiber.resume(result) })
      Fiber.yield
    end
    
    # Fiber-aware EM.system
    #
    def self.system cmd, *args
      fiber = Fiber.current
      EM.system(cmd, *args){ |out, status| fiber.resume( [out, status] ) }
      Fiber.yield
    end

    # Overrides behavior of kernel.sleep
    # Allows to add custom behavior, e.g. logging or redirection to
    # EM::Synchrony.sleep .
    # Calling 'sleep' in this function calls the actual kernel method.
    #
    def self.on_sleep(&blk)
      Kernel.em_synchrony_sleep_hook = blk
    end

    # Routes to EM::Synchrony::Keyboard
    #
    def self.gets
      EventMachine::Synchrony::Keyboard.new.gets
    end

    # Interrupt current fiber to give chance to other fibers
    #
    def self.interrupt
      fiber = Fiber.current
      EM.next_tick { fiber.resume }
      Fiber.yield
    end
  end
end

# Alias for {EventMachine::Synchrony}
EM::S = EventMachine::Synchrony