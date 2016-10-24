require 'em-synchrony'
require 'active_record'
require 'active_record/connection_adapters/abstract/connection_pool'
require 'active_record/connection_adapters/abstract_adapter'
require 'em-synchrony/thread'

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      if Gem::Version.new(::ActiveRecord::VERSION::STRING) >= Gem::Version.new('5.0')
        def connection
          _fibered_mutex.synchronize do
            @thread_cached_conns[connection_cache_key(Thread.current)] ||= checkout
          end
        end
      else
        def connection
          _fibered_mutex.synchronize do
            @reserved_connections[current_connection_id] ||= checkout
          end
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
    module Client
      def open_transactions
        @open_transactions ||= 0
      end

      def open_transactions=(v)
        @open_transactions = v
      end

      def acquired_for_connection_pool
        @acquired_for_connection_pool ||= 0
      end

      def acquired_for_connection_pool=(v)
        @acquired_for_connection_pool = v
      end
    end
    
    module Adapter
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

      def current_transaction #:nodoc:
        @transaction[Fiber.current.object_id] || @closed_transaction
      end

      def transaction_open?
        current_transaction.open?
      end

      def begin_transaction(options = {}) #:nodoc:
        set_current_transaction(current_transaction.begin(options))
      end

      def commit_transaction #:nodoc:
        set_current_transaction(current_transaction.commit)
      end

      def rollback_transaction #:nodoc:
        set_current_transaction(current_transaction.rollback)
      end

      def reset_transaction #:nodoc:
        @transaction = {}
        @closed_transaction = ::ActiveRecord::ConnectionAdapters::ClosedTransaction.new(self)
      end

      # Register a record with the current transaction so that its after_commit and after_rollback callbacks
      # can be called.
      def add_transaction_record(record)
        current_transaction.add_record(record)
      end

      protected

      def set_current_transaction(t)
        if t == @closed_transaction
          @transaction.delete(Fiber.current.object_id)
        else
          @transaction[Fiber.current.object_id] = t
        end
      end
    end

    class ConnectionPool < EM::Synchrony::ConnectionPool

      # consider connection acquired
      def execute(async)
        f = Fiber.current
        begin
          conn = acquire(f)
          conn.acquired_for_connection_pool += 1
          yield conn
        ensure
          conn.acquired_for_connection_pool -= 1
          release(f) if !async && conn.acquired_for_connection_pool == 0
        end
      end

      def acquire(fiber)
        return @reserved[fiber.object_id] if @reserved[fiber.object_id]
        super
      end

      def connection
        acquire(Fiber.current)
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
