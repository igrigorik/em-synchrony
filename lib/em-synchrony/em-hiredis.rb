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
      def self.connect(host = 'localhost', port = 6379)
        conn = new(host, port)
        EM::Synchrony.sync conn.connect
        conn
      end

      def connect
        @connection = EM.connect(@host, @port, Connection, @host, @port)

        @connection.on(:closed) do
          if @connected
            @defs.each { |d| d.fail("Redis disconnected") }
            @defs = []
            @deferred_status = nil
            @connected = false
            unless @closing_connection
              @reconnecting = true
              reconnect
            end
          else
            unless @closing_connection
              EM.add_timer(1) { reconnect }
            end
          end
        end

        @connection.on(:connected) do
          Fiber.new do
            @connected = true

            auth(@password) if @password
            select(@db) if @db

            @subs.each { |s| method_missing(:subscribe, s) }
            @psubs.each { |s| method_missing(:psubscribe, s) }
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
            deferred.fail(reply) if deferred
          else
            if reply && PUBSUB_MESSAGES.include?(reply[0]) # reply can be nil
              kind, subscription, d1, d2 = *reply

              case kind.to_sym
              when :message
                emit(:message, subscription, d1)
              when :pmessage
                emit(:pmessage, subscription, d1, d2)
              end
            else
              if @defs.empty?
                if @monitoring
                  emit(:monitor, reply)
                else
                  raise "Replies out of sync: #{reply.inspect}"
                end
              else
                deferred = @defs.shift
                deferred.succeed(reply) if deferred
              end
            end
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
