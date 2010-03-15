class StubServer
  module Server
    attr_accessor :response, :delay
    def receive_data(data)
      EM.add_timer(@delay) {
        send_data @response
        close_connection_after_writing
      }
    end
  end

  def initialize(response, delay = 0, port=8081)
    @sig = EventMachine::start_server("127.0.0.1", port, Server) { |s|
      s.response = response
      s.delay = delay
    }
  end

  def stop
    EventMachine.stop_server @sig
  end
end
