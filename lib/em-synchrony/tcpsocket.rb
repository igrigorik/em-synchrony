module EventMachine
  module Synchrony
    class TCPSocket < Connection
      class << self
        alias_method :_old_new, :new
        def new(*args)
          if args.size == 1
            _old_new *args
          else
            socket = EventMachine::connect( *args[0..1], self )
            raise SocketError unless socket.sync(:in)  # wait for connection
            socket
          end
        end
        alias :open :new
      end

      def post_init
        @in_buff, @out_buff = '', ''
        @in_req = @out_req = nil
      end

      def closed?
        @in_req.nil? && @out_req.nil?
      end

      # direction must be one of :in or :out
      def sync(direction)
        req = self.instance_variable_set "@#{direction.to_s}_req", EventMachine::DefaultDeferrable.new
        EventMachine::Synchrony.sync req
      end

      # TCPSocket interface
      def setsockopt(level, name, value); end

      def send(msg, flags = 0)
        raise "Unknown flags in send(): #{flags}"  if flags.nonzero?
        len = msg.bytesize
        write_data(msg) or sync(:out) or raise(IOError)
        len
      end
      alias_method :write, :send

      def read(num_bytes = 16*1024, dest = nil)
        read_data(num_bytes, dest) or sync(:in) or raise(IOError)
      end
      alias_method :read_nonblock, :read
      alias_method :recv, :read

      def close
        close_connection true
        @in_req = @out_req = nil
      end

      # EventMachine interface
      def connection_completed
        @in_req.succeed self
      end

      def unbind
        @in_req.fail  nil if @in_req
        @out_req.fail nil if @out_req
      end

      def receive_data(data)
        @in_buff << data
        if @in_req && (data = read_data)
          @in_req.succeed data
        end
      end

      protected
        def read_data(num_bytes = nil, dest = nil)
          @read_bytes = num_bytes  if num_bytes
          @read_dest = dest  if dest
          if @in_buff.size > 0
            data = @in_buff.slice!(0, @read_bytes)
            @read_bytes = 0

            if @read_dest
              @read_dest.replace data
              @read_dest = nil
            end
            data
          else
            nil
          end
        end

        def write_data(data = nil)
          @out_buff += data if data

          loop do
            if @out_buff.empty?
              @out_req.succeed true if @out_req
              return true
            end

            if self.get_outbound_data_size > EventMachine::FileStreamer::BackpressureLevel
              EventMachine::next_tick { write_data }
              return false
            else
              len = [@out_buff.bytesize, EventMachine::FileStreamer::ChunkSize].min
              self.send_data @out_buff.slice!( 0, len )
            end
          end
        end
    end
  end
end