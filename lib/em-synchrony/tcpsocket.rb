module EventMachine
  module Synchrony
    class TCPSocket < Connection
      class << self
        alias_method :_old_new, :new
        def new(*args)
          if args.size == 1
            _old_new(*args)
          else
            # In TCPSocket, new against an unknown hostname raises SocketError with
            # a message "getaddrinfo: nodename nor servname provided, or not known".
            # In EM, connect against an unknown hostname raises EM::ConnectionError
            # with a message of "unable to resolve server address" 
            begin
              socket = EventMachine::connect(*args[0..1], self)
            rescue EventMachine::ConnectionError => e
              raise SocketError, e.message
            end
            # In TCPSocket, new against a closed port raises Errno::ECONNREFUSED.
            # In EM, connect against a closed port result in a call to unbind with
            # a reason param of Errno::ECONNREFUSED as a class, not an instance.
            unless socket.sync(:in)  # wait for connection
              raise socket.unbind_reason.new if socket.unbind_reason.is_a? Class
              raise SocketError
            end
            socket
          end
        end
        alias :open :new
      end

      def post_init
        @in_buff, @out_buff = '', ''
        @in_req = @out_req = @unbind_reason = @read_type = nil
        @opening = true
        @closed = @remote_closed = false
      end

      def closed?
        # In TCPSocket, 
        # closed? on a remotely closed socket, when we've not yet read EOF, returns false
        # closed? on a remotely closed socket, when we've read EOF, returns false
        # closed? on a socket after #close, returns true
        # Therefore, we set @close to true when #close is called, but not when unbind is. 
        @closed
      end

      # direction must be one of :in or :out
      def sync(direction)
        req = self.instance_variable_set "@#{direction.to_s}_req", EventMachine::DefaultDeferrable.new
        EventMachine::Synchrony.sync req
      ensure
        self.instance_variable_set "@#{direction.to_s}_req", nil
      end

      # TCPSocket interface
      def setsockopt(level, name, value); end

      def send(msg, flags)
        raise "Unknown flags in send(): #{flags}" if flags.nonzero?
        # write(X) on a socket after #close, raises IOError with message "closed stream"
        # send(X,0) on a socket after #close, raises IOError with message "closed stream"
        raise IOError, "closed stream" if @closed
        # the first write(X) on a remotely closed socket, <= than some buffer size, generates no error
        # the first write(X) on a remotely closed socket, > than some buffer size, generates no error
        # (on my box this buffer appears to be 80KB)
        # further write(X) on a remotely closed socket, raises Errno::EPIPE
        # the first send(X,0) on a remotely closed socket, <= than some buffer size, generates no error
        # the first send(X,0) on a remotely closed socket, > than some buffer size, generates no error
        # (on my box this buffer appears to be 80KB)
        # further send(X,0) on a remotely closed socket, raises Errno::EPIPE
        raise Errno::EPIPE if @remote_closed
        
        len = msg.bytesize
        # write(X) on an open socket, where the remote end closes during the write, raises Errno::EPIPE
        # send(X,0) on an open socket, where the remote end closes during the write, raises Errno::EPIPE
        write_data(msg) or sync(:out) or raise(Errno::EPIPE)
        len
      end
      
      def write(msg)
        send(msg,0)
      end

      def read(num_bytes = nil, dest = nil)
        handle_read(:read, num_bytes, dest)
      end

      def read_nonblock(maxlen, dest = nil)
        raise ArgumentError, "maxlen must be > 0" if !maxlen || maxlen <= 0
        read_bytes = handle_read(:read_nonblock, maxlen, dest)
        raise EOFError if read_bytes.nil?
        read_bytes
      end

      def recv(num_bytes, flags = 0)
        raise "Unknown flags in recv(): #{flags}" if flags.nonzero?
        handle_read(:recv, num_bytes)
      end
      
      def close
        # close on a closed socket raises IOError with a message of "closed stream"
        raise IOError, "closed stream" if @closed
        @closed = true
        close_connection true
        @in_req = @out_req = nil
        # close on an open socket returns nil
        nil
      end

      # EventMachine interface
      def connection_completed
        @opening = false
        @in_req.succeed self
      end
      
      attr_reader :unbind_reason
      
      # Can't set a default value for reason (e.g. reason=nil), as in that case
      # EM fails to pass in the reason argument and you'll always get the default
      # value.
      def unbind(reason)
        @unbind_reason = reason
        @remote_closed = true unless @closed
        if @opening
          @in_req.fail nil if @in_req
        else
          @in_req.succeed read_data if @in_req
        end
        @out_req.fail nil if @out_req
        @in_req = @out_req = nil
      end

      def receive_data(data)
        @in_buff << data
        if @in_req && (data = read_data)
          @in_req.succeed data unless data == :block
        end
      end

      protected
        def handle_read(type, num_bytes, dest=nil)
          # read(-n) always raises ArgumentError
          # recv(-n) always raises ArgumentError
          raise ArgumentError, "negative length #{num_bytes} given" if num_bytes != nil and num_bytes < 0
          # read(n) on a socket after #close, raises IOError with message "closed stream"
          # read(0) on a socket after #close, raises IOError with message "closed stream"
          # read() on a socket after #close, raises IOError with message "closed stream"
          # recv(n) on a socket after #close, raises IOError with message "closed stream"
          # recv(0) on a socket after #close, raises IOError with message "closed stream"
          raise IOError, "closed stream" if @closed
          # read(0) on an open socket, return ""
          # read(0) on a remotely closed socket, with buffered data, returns ""
          # read(0) on a remotely closed socket, with no buffered data, returns ""
          # recv(0) on an open socket, return ""
          # recv(0) on a remotely closed socket, with buffered data, returns ""
          # recv(0) on a remotely closed socket, with no buffered data, returns ""
          return "" if num_bytes == 0

          @read_type  = type
          @read_bytes = num_bytes
          @read_dest  = dest if dest
          
          (data = read_data) != :block ? data : sync(:in)
        end
        
        def try_read_data
          if @read_type == :read || @read_type == :read_nonblock
            nonblocking = @read_type == :read_nonblock
            unless @remote_closed
              if @read_bytes
                # read(n) on an open socket, with >= than n buffered data, returns n data
                if (@in_buff.size >= @read_bytes ||
                    (nonblocking && @in_buff.size > 0)) then
                  @in_buff.slice!(0, @read_bytes)
                # read(n) on an open socket, with < than n buffered data, blocks
                else :block end
              else
                # read() on an open socket, blocks until a remote close and returns all the data sent
                :block
              end
            else
              if @read_bytes
                # read(n) on a remotely closed socket, with no buffered data, returns nil
                if @in_buff.empty? then nil
                # read(n) on a remotely closed socket, with buffered data, returns the buffered data up to n
                else @in_buff.slice!(0, @read_bytes) end
              else
                # read() on a remotely closed socket, with no buffered data, returns ""
                if @in_buff.empty? then ""
                # read() on a remotely closed socket, with buffered data, returns the buffered data
                else @in_buff.slice!(0, @in_buff.size) end
              end
            end
          else #recv
            unless @remote_closed
              # recv(n) on an open socket, with no buffered data, blocks
              if @in_buff.empty? then :block
              # recv(n) on an open socket, with < than n buffered data, return the buffered data
              # recv(n) on an open socket, with >= than n buffered data, returns n data
              else @in_buff.slice!(0, @read_bytes) end
            else
              # recv(n) on a remotely closed socket, with no buffered data, returns ""
              if @in_buff.empty? then ""
              # recv(n) on a remotely closed socket, with < than n buffered data, return the buffered data
              # recv(n) on a remotely closed socket, with >= than n buffered data, returns n data              
              else @in_buff.slice!(0, @read_bytes) end              
            end
          end
        end
        
        def read_data
          data = try_read_data
          unless data == :block
            @read_bytes = 0
            # read(n,buffer) returns the buffer when it does not return nil or raise an exception
            data = @read_dest.replace(data) if @read_dest and not data.nil?
            @read_dest = nil
          end
          data
        end
        
        def write_data(data = nil)
          @out_buff += data if data

          loop do
            if @out_buff.empty?
              @out_req.succeed true if @out_req
              return true
            end

            if self.get_outbound_data_size > EventMachine::FileStreamer::BackpressureLevel
              # write(X) on an open socket, where the remote end is not reading, > than some buffer size, blocks
              # send(X,0) on an open socket, where the remote end is not reading, > than some buffer size, blocks
              # where that buffer size is EventMachine::FileStreamer::BackpressureLevel, returning false will
              # cause write/send to block
              EventMachine::next_tick { write_data }
              return false
            else
              # write(X) on an open socket, where the remote end is not reading, <= than some buffer size, sends and returns
              # send(X,0) on an open socket, where the remote end is not reading, <= than some buffer size, sends returns
              len = [@out_buff.bytesize, EventMachine::FileStreamer::ChunkSize].min
              self.send_data @out_buff.slice!( 0, len )
            end
          end
        end
    end
  end
end
