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
end
