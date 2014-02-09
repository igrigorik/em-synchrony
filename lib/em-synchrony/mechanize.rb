require 'mechanize'

module EventMachine
  module Synchrony
    class Mechanize < ::Mechanize
      def initialize(*args, &blk)
        super
        @agent.instance_variable_get(:@http).singleton_class.send(:include, DeferedNetHttpPersistentRequest)
      end

      module DeferedNetHttpPersistentRequest
        def self.included(base)
          base.class_eval do
            alias :request_without_defer :request
            alias :request :request_with_defer
          end
        end

        def request_with_defer(*args, &blk)
          EM::Synchrony.defer do
            request_without_defer(*args, &blk)
          end
        end
      end
    end
  end
end
