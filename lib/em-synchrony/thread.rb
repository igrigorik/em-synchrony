module EM::Synchrony
  class Mutex
    def initialize
      @waiters = []
      @current_fiber = nil
    end

    def lock
      raise FiberError if @current_fiber && @current_fiber == Fiber.current  
      if @current_fiber
        @waiters << Fiber.current
        Fiber.yield
      end
      @current_fiber = Fiber.current
      true
    end

    def locked?
      !@current_fiber.nil?
    end

    def sleep(timeout = nil)
      unlock    
      if timeout
        f = Fiber.current
        timer = EM.add_timer(timeout) do
          f.resume
        end
        res = Fiber.yield
        EM.cancel_timer timer # if we resumes not via timer
        res
      else
        Fiber.yield
      end
      lock
    end

    def try_lock
      if @current_fiber
        false
      else
        @current_fiber = Fiber.current
        true
      end
    end

    def unlock
      raise FiberError if @current_fiber != Fiber.current  
      @current_fiber = nil
      if f = @waiters.shift
        f.resume
      end
    end

    def synchronize(&blk)
      lock
      blk.call
    ensure
      unlock
    end

  end

  class ConditionVariable
    #
    # Creates a new ConditionVariable
    #
    def initialize
      @waiters = []
    end

    #
    # Releases the lock held in +mutex+ and waits; reacquires the lock on wakeup.
    #
    # If +timeout+ is given, this method returns after +timeout+ seconds passed,
    # even if no other thread doesn't signal.
    #
    def wait(mutex, timeout=nil)
      begin
        @waiters << Fiber.current
        mutex.sleep timeout
      end
      self
    end

    #
    # Wakes up the first thread in line waiting for this lock.
    #
    def signal
      begin
        f = @waiters.shift
        f.resume if f
      rescue FiberError
        retry
      end
      self
    end

    #
    # Wakes up all threads waiting for this lock.
    #
    def broadcast
      # TODO: imcomplete
      waiters0 = nil
      waiters0 = @waiters.dup
      @waiters.clear
      waiters0.each do |f|
        begin
          f.resume
        rescue FiberError
        end
      end
      self
    end
  end

  module MonitorMixin
    class ConditionVariable
      class Timeout < Exception; end
      def initialize(monitor)
        @monitor = monitor
        @cond = EM::Synchrony::ConditionVariable.new
      end

      def wait(timeout = nil)
        @monitor.__send__(:_mon_check_owner)
        count = @monitor.__send__(:_mon_exit_for_cond)
        begin
          @cond.wait(@monitor.instance_variable_get("@mon_mutex"), timeout)
          return true
        ensure
          @monitor.__send__(:_mon_enter_for_cond, count)
        end
      end

      def wait_while
        while yield
          wait
        end
      end

      def wait_until
        until yield
          wait
        end
      end

      def signal
        @monitor.__send__(:_mon_check_owner)
        @cond.signal
      end

      def broadcast
        @monitor.__send__(:_mon_check_owner)
        @cond.broadcast
      end
    end

    def self.extend_object(obj)
      super(obj)
      obj.__send__(:_mon_initialize)
    end

    def initialize(*args)
      super
      _mon_initialize
    end

    def mon_try_enter
      if @mon_owner != Fiber.current
        unless @mon_mutex.try_lock
          return false
        end
        @mon_owner = Fiber.current
      end
      @mon_count += 1
      return true
    end
    
    def mon_enter
      if @mon_owner != Fiber.current
        @mon_mutex.lock
        @mon_owner = Fiber.current
      end
      @mon_count += 1
    end

    #
    # Leaves exclusive section.
    #
    def mon_exit
      _mon_check_owner
      @mon_count -=1
      if @mon_count == 0
        @mon_owner = nil
        @mon_mutex.unlock
      end
    end

    def mon_synchronize
      mon_enter
      begin
        yield
      rescue => e
        require 'pp'
        puts e
        pp e.backtrace
      ensure
        mon_exit
      end
    end
    alias synchronize mon_synchronize

    def new_cond
      return ConditionVariable.new self
    end

    def _mon_initialize
      @mon_owner = nil
      @mon_count = 0
      @mon_mutex = EM::Synchrony::Mutex.new
    end

    def _mon_check_owner
      if @mon_owner != Fiber.current
        raise FiberError, "current fiber not owner"
      end
    end

    def _mon_enter_for_cond(count)
      @mon_owner = Fiber.current
      @mon_count = count
    end

    def _mon_exit_for_cond
      count = @mon_count
      @mon_owner = nil
      @mon_count = 0
      return count
    end
  end

  class Monitor
    include MonitorMixin
    alias try_enter mon_try_enter
    alias enter mon_enter
    alias exit mon_exit
  end
end