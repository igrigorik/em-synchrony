require 'active_record'
require 'active_record/connection_adapters/abstract/connection_pool'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'
require 'em-synchrony/thread'

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      def connection
        _fibered_mutex.synchronize do
          @reserved_connections[current_connection_id] ||= checkout
        end
      end

      def _fibered_mutex
        @fibered_mutex ||= EM::Synchrony::Thread::Mutex.new
      end
    end
  end
end

module EM::Synchrony
  module ActiveRecord
    class Mysql2Client < Mysql2::EM::Client
      attr_accessor :open_transactions
      attr_accessor :acquired
    end

    class Adapter < ::ActiveRecord::ConnectionAdapters::Mysql2Adapter
      def configure_connection
        nil
      end

      def transaction(*args, &blk)
        @connection.execute(false) do |conn|
          super
        end
      end

      def real_connection
        @connection.connection
      end

      def open_transactions
        real_connection.open_transactions
      end

      def increment_open_transactions
        real_connection.open_transactions += 1
      end

      def decrement_open_transactions
        real_connection.open_transactions -= 1
      end
    end

    class ConnectionPool < EM::Synchrony::ConnectionPool

      # consider connection acquired
      def execute(async)
        f = Fiber.current
        begin
          conn = acquire(f)
          conn.acquired += 1
          yield conn
        ensure
          conn.acquired -= 1
          release(f) if !async && conn.acquired == 0
        end
      end

      # via method_missing affected_rows will be recognized as async method
      def affected_rows(*args, &blk)
        execute(false) do |conn|
          conn.send(:affected_rows, *args, &blk)
        end
      end
    end
  end
end