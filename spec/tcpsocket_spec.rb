require "spec/helper/core"

module SendAndClose
  def post_init
    send_data "1234"
    close_connection_after_writing
  end
end

module SendAndTimedClose
  def post_init
    send_data "1234"
    EM.add_timer(0.05) { self.close_connection_after_writing }
  end
end

module SendAndKeepOpen
  def post_init
    send_data "1234"
  end
end

def tcp_test(server_type, ops={}, &block)
  EventMachine.synchrony do
    ops = {:stop => true}.merge ops
    EM::start_server('localhost', 12345, server_type)
    @socket = EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
    @socket.close if ops[:close]
    block.call
    EM.stop if ops[:stop]
  end
end

describe EventMachine::Synchrony::TCPSocket  do
  context '.new' do
    context 'to an open TCP port on an resolvable host' do
      it 'succeeds'  do
        EventMachine.synchrony do
          EM::start_server('localhost', 12345)
          @socket = EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
          @socket.should_not be_error
          EM.stop
        end
      end
    end

    context 'to an unresolvable host' do
      it 'raises SocketError' do
        EventMachine.synchrony do
          proc {
            EventMachine::Synchrony::TCPSocket.new 'xxxyyyzzz', 12345
          }.should raise_error(SocketError)
          EM.stop
        end
      end
    end

    context 'to a closed TCP port' do
      it 'raises Errno::ECONNREFUSED' do
        EventMachine.synchrony do
          proc {
            EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
          }.should raise_error(Errno::ECONNREFUSED)
          EM.stop
        end
      end
    end
  end
  
  context '#closed?' do
    context 'after calling #close' do
      it 'returns true' do
        tcp_test(SendAndKeepOpen, :close => true) do
          @socket.should be_closed
        end
      end
    end
    context 'after the peer has closed the connection' do
      context 'when we\'ve not yet read EOF' do
        it 'returns false' do
          tcp_test(SendAndClose) do
            @socket.read(2).size.should eq 2
            @socket.should_not be_closed
          end
        end
      end
      context 'when we\'ve read EOF' do
        it 'returns false' do
          tcp_test(SendAndClose) do
            @socket.read(10).size.should  < 10
            @socket.read(10).should be_nil
            @socket.should_not be_closed
          end
        end
      end
    end
  end
  
  context '#read' do
    context 'with a length argument' do
      context 'with a possitive length argument' do
        context 'when the connection is open' do
          context 'with greater or equal than the requested data buffered' do
            it 'returns the requested data and no more' do
              tcp_test(SendAndKeepOpen) do
                @socket.read(2).size.should eq 2
                @socket.read(1).size.should eq 1
              end
            end
          end
          context 'with less than the requested data buffered' do
            it 'blocks' do
              tcp_test(SendAndKeepOpen, :stop => false) do
                @blocked = true
                EM.next_tick { @blocked.should eq true;  EM.next_tick { EM.stop } }
                @socket.read(10)
                @blocked = false
              end
            end
          end
        end
        context 'when the peer has closed the connection' do
          context 'with no data buffered' do
            it 'returns nil' do
              tcp_test(SendAndClose) do
                @socket.read(4).size.should eq 4
                @socket.read(1).should be_nil
              end
            end
          end
          context 'with less than the requested data buffered' do
            it 'returns the buffered data' do
              tcp_test(SendAndClose) do
                @socket.read(50).size.should eq 4
              end
            end
          end
          context 'with greater or equal than the requested data buffered' do
            it 'returns the requested data and no more' do
              tcp_test(SendAndClose) do
                @socket = EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
                @socket.read(2).size.should eq 2
              end
            end
          end
        end
        context 'when we closed the connection' do
          it 'raises IOError' do
            tcp_test(SendAndKeepOpen, :close => true) do
              proc {
                @socket.read(4)
              }.should raise_error(IOError)
            end
          end
        end
      end
      context 'with a negative length argument' do
        it 'raises ArgumentError' do
          tcp_test(SendAndKeepOpen) do
            proc {
              @socket.read(-10)
            }.should raise_error(ArgumentError)
          end
        end
      end
      context 'with a zero length argument' do
        context 'when the connection is open' do
          it 'returns an empty string' do
            tcp_test(SendAndKeepOpen) do
              @socket.read(0).should eq ""
            end
          end
        end
        context 'when the peer has closed the connection' do
          it 'returns an empty string' do
            tcp_test(SendAndClose) do
              @socket.read(0).should eq ""
            end
          end
        end
        context 'when we closed the connection' do
          it 'raises IOError' do
            tcp_test(SendAndKeepOpen, :close => true) do
              proc {
                @socket.read(0)
              }.should raise_error(IOError)
            end
          end
        end
      end
    end
    context 'without a length argument' do
      context 'when the connection is open' do
        it 'blocks until the peer closes the connection and returns all data sent' do
          tcp_test(SendAndTimedClose) do
            @blocked = true
            EM.next_tick { @blocked.should eq true }
            @socket.read(10).should eq '1234'
            @blocked = false
          end
        end
      end
      context 'when the peer has closed the connection' do
        context 'with no data buffered' do
          it 'returns an empty string' do
            tcp_test(SendAndClose) do
              @socket.read()
              @socket.read().should eq ""
            end
          end
        end
        context 'with data buffered' do
          it 'returns the buffered data' do
            tcp_test(SendAndClose) do
              @socket.read().should eq "1234"
            end
          end
        end
      end
      context 'when we closed the connection' do
        it 'raises IOError' do
          tcp_test(SendAndKeepOpen, :close => true) do
            proc {
              @socket.read()
            }.should raise_error(IOError)
          end
        end
      end
    end
  end
  
  context '#read_nonblock' do
    context 'with a positive length argument' do
      context 'when the connection is open' do
        context 'with greater or equal than the requested data buffered' do
          it 'returns the requested data and no more' do
            tcp_test(SendAndKeepOpen) do
              @socket.read_nonblock(2).size.should eq 2
              @socket.read_nonblock(1).size.should eq 1
            end
          end
        end
        context 'with less than the requested data buffered' do
          it 'returns the available data' do
            tcp_test(SendAndKeepOpen) do
              @socket.read_nonblock(10).size.should eq 4
            end
          end
        end
      end
      context 'when the peer has closed the connection' do
        context 'with no data buffered' do
          it 'raises EOFError' do
            tcp_test(SendAndClose) do
              @socket.read_nonblock(4).size.should eq 4
              lambda {
                @socket.read_nonblock(1)
              }.should raise_error(EOFError)
            end
          end
        end
        context 'with less than the requested data buffered' do
          it 'returns the buffered data' do
            tcp_test(SendAndClose) do
              @socket.read_nonblock(50).size.should eq 4
            end
          end
        end
        context 'with greater or equal than the requested data buffered' do
          it 'returns the requested data and no more' do
            tcp_test(SendAndClose) do
              @socket = EventMachine::Synchrony::TCPSocket.new 'localhost', 12345
              @socket.read_nonblock(2).size.should eq 2
            end
          end
        end
      end
      context 'when we closed the connection' do
        it 'raises IOError' do
          tcp_test(SendAndKeepOpen, :close => true) do
            proc {
              @socket.read_nonblock(4)
            }.should raise_error(IOError)
          end
        end
      end
    end
    context 'with a negative length argument' do
      it 'raises ArgumentError' do
        tcp_test(SendAndKeepOpen) do
          proc {
            @socket.read_nonblock(-10)
          }.should raise_error(ArgumentError)
        end
      end
    end
    context 'with a zero length argument' do
      it 'raises ArgumentError' do
        tcp_test(SendAndKeepOpen) do
          proc {
            @socket.read_nonblock(0)
          }.should raise_error(ArgumentError)
        end
      end
    end
  end

  context '#recv' do
    context 'with a length argument' do
      context 'with a possitive length argument' do
        context 'when the connection is open' do
          context 'with greater or equal than the requested data buffered' do
            it 'returns the requested data and no more' do
              tcp_test(SendAndKeepOpen) do
                @socket.recv(2).size.should eq 2
                @socket.recv(1).size.should eq 1
              end
            end
          end
          context 'with less than the requested data buffered' do
            it 'return the buffered data' do
              tcp_test(SendAndKeepOpen) do
                @socket.recv(50).size.should eq 4
              end
            end
          end
          context 'with no buffered data' do
            it 'blocks' do
              tcp_test(SendAndKeepOpen, :stop => false) do
                @socket.recv(10)
                @blocked = true
                EM.next_tick { @blocked.should eq true;  EM.next_tick { EM.stop } }
                @socket.recv(10)
                @blocked = false
              end
            end
          end
        end
        context 'when the peer has closed the connection' do
          context 'with no data buffered' do
            it 'returns an empty string' do
              tcp_test(SendAndClose) do
                @socket.read(4).size.should eq 4
                @socket.recv(1).should eq ""
              end
            end
          end
          context 'with less than the requested data buffered' do
            it 'returns the buffered data' do
              tcp_test(SendAndClose) do
                @socket.recv(50).size.should eq 4
              end
            end
          end
          context 'with greater or equal than the requested data buffered' do
            it 'returns the requested data and no more' do
              tcp_test(SendAndClose) do
                @socket.recv(2).size.should eq 2
              end
            end
          end
        end
        context 'when we closed the connection' do
          it 'raises IOError' do
            tcp_test(SendAndKeepOpen, :close => true) do
              proc {
                @socket.recv(4)
              }.should raise_error(IOError)
            end
          end
        end
      end
      context 'with a negative length argument' do
        it 'raises ArgumentError' do
          tcp_test(SendAndKeepOpen) do
            proc {
              @socket.recv(-10)
            }.should raise_error(ArgumentError)
          end
        end
      end
      context 'with a zero length argument' do
        context 'when the connection is open' do
          it 'returns an empty string' do
            tcp_test(SendAndKeepOpen) do
              @socket.recv(0).should eq ""
            end
          end
        end
        context 'when the peer has closed the connection' do
          it 'returns an empty string' do
            tcp_test(SendAndClose) do
              @socket.recv(0).should eq ""
            end
          end
        end
        context 'when we closed the connection' do
          it 'raises IOError' do
            tcp_test(SendAndKeepOpen, :close => true) do
              proc {
                @socket.recv(0)
              }.should raise_error(IOError)
            end
          end
        end
      end
    end
    context 'without a length argument' do
      it 'raises ArgumentError' do
        tcp_test(SendAndKeepOpen) do
          proc {
            @socket.recv()
          }.should raise_error(ArgumentError)
        end
      end
    end
  end
  
  context '#write' do
    context 'when the peer has closed the connection' do
      it 'raises Errno::EPIPE' do
        tcp_test(SendAndClose, :stop => false) do
          EM.add_timer(0.01) do
            proc {
              @socket.write("foo")
            }.should raise_error(Errno::EPIPE)
            EM.stop
          end
        end
      end
    end
    context 'when we closed the connection' do
      it 'raises IOError' do
        tcp_test(SendAndKeepOpen, :close => true) do
          proc {
            @socket.write("foo")
          }.should raise_error(IOError)
        end
      end
    end
  end
  
  context '#send' do
    context 'when the peer has closed the connection' do
      it 'raises Errno::EPIPE' do
        tcp_test(SendAndClose, :stop => false) do
          EM.add_timer(0.01) do
            proc {
              @socket.send("foo",0)
            }.should raise_error(Errno::EPIPE)
            EM.stop
          end
        end
      end
    end
    context 'when we closed the connection' do
      it 'raises IOError' do
        tcp_test(SendAndKeepOpen, :close => true) do
          proc {
            @socket.send("foo",0)
          }.should raise_error(IOError)
        end
      end
    end
    context 'without a flags argument' do
      it 'raises ArgumentError' do
        tcp_test(SendAndKeepOpen) do
          proc {
            @socket.send('foo')
          }.should raise_error(ArgumentError)
        end
      end
    end
  end
  
  context 'when wrapped in a connection pool' do
    it 'accepts "send"' do
      EventMachine.synchrony do
        @socket = EventMachine::Synchrony::ConnectionPool.new(size: 1) do
          EventMachine::Synchrony::TCPSocket.new 'eventmachine.rubyforge.org', 80
        end
        @socket.send("GET / HTTP1.1\r\n\r\n",0).class.should be(Fixnum)
        EM.stop
      end
    end
  end
end
