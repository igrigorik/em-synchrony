require 'active_record'
require 'active_record/connection_adapters/abstract/connection_pool'
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
        @fibered_mutex ||= EM::Synchrony::Mutex.new
      end
    end
  end
end