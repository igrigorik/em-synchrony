module EventMachine
  module Synchrony
    module Thread

      # Fiber-aware drop-in replacements for thread objects
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
        def wait( mutex )
          @deferrable = EventMachine::DefaultDeferrable.new
          EventMachine::Synchrony.sync @deferrable
          @deferrable = nil
        end

        def signal
          @deferrable and @deferrable.succeed
        end
      end

    end
  end
end
