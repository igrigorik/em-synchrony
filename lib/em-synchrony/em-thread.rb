module EventMachine
  module Synchrony
    module Thread

      # Fiber-aware drop-in replacements for thread objects
      class Mutex
        def synchronize( &blk )
          blk.call
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
