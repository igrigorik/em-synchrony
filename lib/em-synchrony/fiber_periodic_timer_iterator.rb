module EventMachine
  module Synchrony

    class FiberPeriodicTimerIterator < EM::Synchrony::Iterator

      # set timeout and start point
      # each Fiber will be executed not earlier than once per timeout
      def initialize(list, concurrency=1, timeout=0)
        @timeout = timeout
        @next_start = Time.now
        super list, concurrency
      end

      # execute each iterator block within its own fiber at particular time offset
      # and auto-advance the iterator after each call
      def each(foreach=nil, after=nil, &blk)
        fe = Proc.new do |obj, iter|
          Fiber.new do
            sleep
            (foreach || blk).call(obj); iter.next
          end.resume
        end
        super(fe, after)
      end

      # Sleep if the last request was recently (less then timout period)
      def sleep
        if @timeout > 0
          now = Time.now
          sleep_time = @next_start - Time.now
          sleep_time = 0 if sleep_time < 0
          @next_start = Time.now + sleep_time + @timeout
          EM::Synchrony.sleep(sleep_time) if sleep_time > 0
        end
      end

    end
  end
end
