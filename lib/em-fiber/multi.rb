module EventMachine
  class Multi
    include EventMachine::Deferrable

    attr_reader :requests, :responses

    def initialize
      @requests = []
      @responses = {:callback => [], :errback => []}
    end

    def add(conn)
      conn.callback { @responses[:callback].push(conn); check_progress }
      conn.errback  { @responses[:errback].push(conn);  check_progress }

      @requests.push(conn)
    end
    alias :push :add
    alias :<<   :add

    def perform
      @fiber = Fiber.current
      Fiber.yield
    end

    protected
    
      def check_progress
        if (@responses[:callback].size + @responses[:errback].size) == @requests.size
          succeed

          # continue processing
          @fiber.resume(self) if @fiber
        end
      end
  end
end
