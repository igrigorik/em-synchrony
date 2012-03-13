module EventMachine
  module Synchrony
    module Thread

      # Fiber-aware drop-in replacements for thread objects
      class Mutex
        def initialize
          @waiters = []
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

        def sleep(timeout = nil)
          unlock    
          beg = Time.now
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
          begin
            @waiters << current
            mutex.sleep timeout
          ensure
            @waiters.delete current
          end
          self
        end

        #
        # Wakes up the first thread in line waiting for this lock.
        #
        def signal
          while f = @waiters.shift
            if f.alive?
              # XXX Should we rescue from FiberError?
              EM.next_tick{ f.resume }
              break
            end
          end
          self
        end

        #
        # Wakes up all threads waiting for this lock.
        #
        def broadcast
          # TODO: imcomplete
          waiters0 = @waiters.dup
          @waiters.clear
          waiters0.each do |f|
            if f.alive?
              # XXX Should we rescue from FiberError?
              EM.next_tick{ f.resume }
            end
          end
          self
        end
      end

    end
  end
end
