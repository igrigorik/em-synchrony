require 'em-synchrony/thread'

module EventMachine
  module Synchrony

    # Fiber-aware drop-in replacements for MonitorMixin
    module MonitorMixin
      class ConditionVariable < ::MonitorMixin::ConditionVariable
        private

        def initialize(monitor)
          @monitor = monitor
          @cond = EventMachine::Synchrony::Thread::ConditionVariable.new
        end
      end

      def self.extend_object(obj)
        super(obj)
        obj.__send__(:mon_initialize)
      end


      #
      # Attempts to enter exclusive section.  Returns +false+ if lock fails.
      #
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
      # For backward compatibility
      alias try_mon_enter mon_try_enter

      #
      # Enters exclusive section.
      #
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
        mon_check_owner
        @mon_count -=1
        if @mon_count == 0
          @mon_owner = nil
          @mon_mutex.unlock
        end
      end

      #
      # Enters exclusive section and executes the block.  Leaves the exclusive
      # section automatically when the block exits.  See example under
      # +MonitorMixin+.
      #
      def mon_synchronize
        mon_enter
        begin
          yield
        ensure
          mon_exit
        end
      end
      alias synchronize mon_synchronize

      #
      # Creates a new Synchrony::MonitorMixin::ConditionVariable associated with the
      # receiver.
      #
      def new_cond
        return ConditionVariable.new(self)
      end

      private

      def initialize(*args)
        super
        mon_initialize
      end

      def mon_initialize
        @mon_owner = nil
        @mon_count = 0
        @mon_mutex = EventMachine::Synchrony::Thread::Mutex.new
      end

      def mon_check_owner
        if @mon_owner != Fiber.current
          raise FiberError, "current fiber not owner"
        end
      end

      def mon_enter_for_cond(count)
        @mon_owner = Fiber.current
        @mon_count = count
      end

      def mon_exit_for_cond
        count = @mon_count
        @mon_owner = nil
        @mon_count = 0
        return count
      end
    end

    # Fiber-aware drop-in replacements for Monitor
    class Monitor
      include MonitorMixin
      alias try_enter try_mon_enter
      alias enter mon_enter
      alias exit mon_exit
    end
  end
end
