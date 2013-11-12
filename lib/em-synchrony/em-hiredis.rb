begin
  require 'em-hiredis'
rescue LoadError => error
  raise 'Missing EM-Synchrony dependency: gem install em-hiredis'
end

module EventMachine
  module Hiredis
    
    def self.connect(uri = nil)
      client = setup(uri)
      EM::Synchrony.sync client.connect
      client
    end
    
    class Client
      def pubsub
        return @pubsub if @pubsub

        client = PubsubClient.new(@host, @port, @password, @db)
        EM::Synchrony.sync client.connect
        @pubsub = client
      end
    end
    
    class BaseClient
      def self.connect(host = 'localhost', port = 6379)
        conn = new(host, port)
        EM::Synchrony.sync conn.connect
        conn
      end
      
      def connect
        @auto_reconnect = true
        @connection = EM.connect(@host, @port, Connection, @host, @port)
        
        @connection.on(:closed) do
          if @connected
            @defs.each { |d| d.fail(Error.new("Redis disconnected")) }
            @defs = []
            @deferred_status = nil
            @connected = false
            if @auto_reconnect
              # Next tick avoids reconnecting after for example EM.stop
              EM.next_tick { reconnect }
            end
            emit(:disconnected)
            EM::Hiredis.logger.info("#{@connection} Disconnected")
          else
            if @auto_reconnect
              @reconnect_failed_count += 1
              @reconnect_timer = EM.add_timer(EM::Hiredis.reconnect_timeout) {
                @reconnect_timer = nil
                reconnect
              }
              emit(:reconnect_failed, @reconnect_failed_count)
              EM::Hiredis.logger.info("#{@connection} Reconnect failed")
              
              if @reconnect_failed_count >= 4
                emit(:failed)
                self.fail(Error.new("Could not connect after 4 attempts"))
              end
            end
          end
        end
        
        @connection.on(:connected) do
          Fiber.new do
            @connected = true
            @reconnect_failed_count = 0
            @failed = false
            
            select(@db) unless @db == 0
            auth(@password) if @password
            
            @command_queue.each do |df, command, args|
              @connection.send_command(command, args)
              @defs.push(df)
            end
            @command_queue = []
            
            emit(:connected)
            EM::Hiredis.logger.info("#{@connection} Connected")
            succeed
            
            if @reconnecting
              @reconnecting = false
              emit(:reconnected)
            end
          end.resume
        end
        
        @connection.on(:message) do |reply|
          if RuntimeError === reply
            raise "Replies out of sync: #{reply.inspect}" if @defs.empty?
            deferred = @defs.shift
            error = RedisError.new(reply.message)
            error.redis_error = reply
            deferred.fail(error) if deferred
          else
            handle_reply(reply)
          end
        end
        
        @connected = false
        @reconnecting = false
        
        return self
      end
      
      alias :old_method_missing :method_missing
      def method_missing(sym, *args)
        EM::Synchrony.sync old_method_missing(sym, *args)
      end
    end
  end
end
