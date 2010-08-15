module EventMachine
  class TCPSocket < Connection
    class << self
      alias_method :_old_new, :new
      def new( *args )
        if args.size == 1
          _old_new *args
        else
          socket = EventMachine::connect( *args[0..1], self )
          socket.sync  # wait for connection
        end
      end
    end

    def initialize( *args )
      super
      @in_buff = ''
      @want_bytes = 0
      @req = nil
    end

    # TCPSocket interface
    def setsockopt( level, name, value )
    end

    # TODO: add streaming output
    def send( msg, flags = 0 )
      raise "Unknown flags: #{flags}"  if flags.nonzero?
      send_data msg
    end

    def recv( num_bytes )
      get_bytes(num_bytes) || sync
    end

    def close
      close_connection true
    end

    # EventMachine interface
    def connection_completed
      @req.succeed self
    end

    def receive_data( data = '' )
      @in_buff << data
      if @req && (data = get_bytes)
        @req.succeed data
      end
    end

    def get_bytes( want = nil )
      @want_bytes = want  if want
      if @want_bytes <= @in_buff.size
        bytes = @in_buff.slice!(0, @want_bytes)
        @want_bytes = 0
        bytes
      else
        nil
      end
    end

    def sync
      @req = EventMachine::DefaultDeferrable.new
      EventMachine::Synchrony.sync( @req )
    end
  end
end