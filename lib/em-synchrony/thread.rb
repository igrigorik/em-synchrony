module EventMachine
  module Synchrony
    module Thread

      # Fiber-aware drop-in replacements for thread objects
      class Mutex
        def initialize
          @waiters = []
          @slept = {}
        end

        def lock
          current = Fiber.current
          raise FiberError if @waiters.include?(current)
          @waiters << current
          Fiber.yield unless @waiters.first == current
          true
        end

        def locked?
          !@waiters.empty?
        end

        def _wakeup(fiber)
          fiber.resume if @slept.delete(fiber)
        end

        def sleep(timeout = nil)
          unlock    
          beg = Time.now
          current = Fiber.current
          @slept[current] = true
          if timeout
            timer = EM.add_timer(timeout) do
              _wakeup(current)
            end
            Fiber.yield
            EM.cancel_timer timer # if we resumes not via timer
          else
            Fiber.yield
          end
          @slept.delete current
          yield if block_given?
          lock
          Time.now - beg
        end

        def try_lock
          lock unless locked?
        end

        def unlock
          raise FiberError unless @waiters.first == Fiber.current  
          @waiters.shift
          unless @waiters.empty?
            EM.next_tick{ @waiters.first.resume }
          end
          self
        end

        def synchronize
          lock
          yield
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
          current = Fiber.current
          pair = [mutex, current]
          @waiters << pair
          mutex.sleep timeout do
            @waiters.delete pair
          end
          self
        end

        def _wakeup(mutex, fiber)
          if alive = fiber.alive?
            EM.next_tick {
              mutex._wakeup(fiber)
            }
          end
          alive
        end

        #
        # Wakes up the first thread in line waiting for this lock.
        #
        def signal
          while (pair = @waiters.shift)
            break if _wakeup(*pair)
          end
          self
        end

        #
        # Wakes up all threads waiting for this lock.
        #
        def broadcast
          @waiters.each do |mutex, fiber|
            _wakeup(mutex, fiber)
          end
          @waiters.clear
          self
        end
      end

    end
  end
end
