$:.unshift(File.dirname(__FILE__) + '/../lib')

require "eventmachine"

begin
  require "fiber"
rescue LoadError => error
  raise error unless defined? Fiber
end

require "em-synchrony/thread"
require "em-synchrony/em-multi"
require "em-synchrony/tcpsocket"
require "em-synchrony/connection_pool"
require "em-synchrony/keyboard"
require "em-synchrony/iterator"  if EventMachine::VERSION > '0.12.10'

module EventMachine

  # A convenience method for wrapping EM.run body within
  # a Ruby Fiber such that async operations can be transparently
  # paused and resumed based on IO scheduling.
  def self.synchrony(blk=nil, tail=nil, &block)
    blk ||= block
    context = Proc.new { Fiber.new { blk.call }.resume }

    self.run(context, tail)
  end

  module Synchrony

    # sync is a close relative to inclineCallbacks from Twisted (Python)
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
      xback = proc {|r|
        if f == Fiber.current
          return r
        else
          f.resume r
        end
      }
      df.callback &xback
      df.errback &xback

      Fiber.yield
    end

    # a Fiber-aware sleep function using an EM timer
    def self.sleep(secs)
      fiber = Fiber.current
      EM::Timer.new(secs) { fiber.resume }
      Fiber.yield
    end

    def self.add_timer(interval, &blk)
      EM.add_timer(interval) do
        Fiber.new { blk.call }.resume
      end
    end

    def self.add_periodic_timer(interval, &blk)
      EM.add_periodic_timer(interval) do
        Fiber.new { blk.call }.resume
      end
    end
    
    # routes to EM::Synchrony::Keyboard
    def self.gets
      EventMachine::Synchrony::Keyboard.new.gets
    end
  end
end
