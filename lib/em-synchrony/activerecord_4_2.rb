require 'active_record'

module EM::Synchrony
  module ActiveRecord
    module Adapter_4_2
      def configure_connection
        nil
      end

      def transaction(*args)
        @connection.execute(false) do |conn|
          super
        end
      end

      def reset_transaction #:nodoc:
        @transaction_manager = TransactionManager.new(self)
      end
    end

    class TransactionManager < ::ActiveRecord::ConnectionAdapters::TransactionManager
      def initialize(*args)
        super
        @stack = Hash.new { |h, k| h[k] = [] }
      end

      def current_transaction #:nodoc:
        _current_stack.last || NULL_TRANSACTION
      end

      def open_transactions
        _current_stack.size
      end

      def begin_transaction(options = {}) #:nodoc:
        transaction =
          if _current_stack.empty?
            ::ActiveRecord::ConnectionAdapters::RealTransaction.new(@connection, options)
          else
            ::ActiveRecord::ConnectionAdapters::SavepointTransaction.new(@connection, "active_record_#{Fiber.current.object_id}_#{open_transactions}", options)
          end
        _current_stack.push(transaction)
        transaction
      end

      def commit_transaction #:nodoc:
        _current_stack.pop.commit
      end

      def rollback_transaction #:nodoc:
        _current_stack.pop.rollback
      end

      private

      def _current_stack
        @stack[Fiber.current.object_id]
      end
    end
  end
end
