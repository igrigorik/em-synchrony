require "spec/helper/all"

describe EventMachine::Synchrony::TCPSocket  do
  it 'connects to a TCP port'  do
    EventMachine.synchrony do
      @socket = EventMachine::Synchrony::TCPSocket.new 'eventmachine.rubyforge.org', 80
      @socket.should_not be_error
      EM.stop
    end
  end

  it 'errors on connection failure' do
    EventMachine.synchrony do
      proc {
        EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
      }.should raise_error(SocketError)
      EM.stop
    end
  end
  
  describe '#read' do
    it 'waits until EOF' do
      module EOFTest
        def post_init
          self.send_data "123"
          EventMachine::add_timer(0.5) { self.close_connection_after_writing }
        end
      end
      EventMachine.synchrony do
        EventMachine::start_server 'localhost', 12345, EOFTest
        @socket = EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
        @socket.read(6).should == '123'
        EventMachine::Synchrony::sleep(1)
        @socket.read(6).should be_nil
        EM.stop
      end
    end
    it 'waits until there is enough data' do
      module EOFTest
        def post_init
          send_data "123"
          EventMachine::add_timer(0.5) { self.send_data "4567890" }
        end
      end
      EventMachine.synchrony do
        EventMachine::start_server 'localhost', 12345, EOFTest
        @socket = EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
        @socket.read(6).should == '123456'
        EM.stop
      end
    end
  end
end
