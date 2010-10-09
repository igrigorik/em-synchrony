module EventMachine
  module Synchrony
    class Multi
      include EventMachine::Deferrable

      attr_reader :requests, :responses

      def initialize
        @requests = []
        @responses = {:callback => {}, :errback => {}}
      end

      def add(name, conn)
        fiber = Fiber.current
        conn.callback { @responses[:callback][name] = conn; check_progress(fiber) }
        conn.errback  { @responses[:errback][name]  = conn; check_progress(fiber) }

        @requests.push(conn)
      end

      def finished?
        (@responses[:callback].size + @responses[:errback].size) == @requests.size
      end

      def perform
        Fiber.yield unless finished?
      end

      protected

        def check_progress(fiber)
          if finished?
            succeed

            # continue processing
            fiber.resume(self) if fiber.alive? && fiber != Fiber.current
          end
        end
    end
  end
end
