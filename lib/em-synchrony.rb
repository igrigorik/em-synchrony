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
          return *args
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

    def self.wait_next_tick
      fiber = Fiber.current
      EM.next_tick { fiber.resume }
      Fiber.yield
    end

    # Fiber-aware EventMachine timer: wraps the passed in
    # block within a new fiber context such that you can
    # continue using synchrony methods
    #
    def self.add_timer(interval, &blk)
      EM.add_timer(interval) do
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

    # Routes to EM::Synchrony::Keyboard
    #
    def self.gets
      EventMachine::Synchrony::Keyboard.new.gets
    end

    module TrampolineHandler
      def read_deferrables
        @read_deferrables ||= []
      end

      def write_deferrables
        @write_deferrables ||= []
      end

      def notify_readable
        self.notify_readable = false
        rd = read_deferrables
        @read_deferrables = []
        rd.each(&:succeed)
      end

      def notify_writable
        self.notify_writable = false
        wd = write_deferrables
        @write_deferrables = []
        wd.each(&:succeed)      
      end

      def unbind
        wd = write_deferrables
        @write_deferrables = []
        rd = read_deferrables
        @read_deferrables = []
        EM::Synchrony.trampoline_connections.delete @fd
        wd.each(&:succeed)
        rd.each(&:succeed)
      end
    end

    def self.trampoline_connections
      @trampoline_connections ||= {}
    end

    # Wait fd
    # TODO: exceptions
    def self.trampoline(fd, options = {})
      deferrable = EM::DefaultDeferrable.new
      deferrable.timeout options[:timeout] if options[:timeout]
      conn = trampoline_connections[fd] ||= EM.watch(fd, TrampolineHandler)
      if options[:read]
        conn.notify_readable = true
        conn.read_deferrables << deferrable
      end
      if options[:write]
        conn.notify_writable = true
        conn.write_deferrables << deferrable
      end    
      EM::Synchrony.sync deferrable
    end
  end
end
