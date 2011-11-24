begin
  require "amqp"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install amqp"
end

module EventMachine
  module Synchrony
    module AMQP

      class << self
        def sync &blk
          fiber = Fiber.current
          blk.call(fiber)
          Fiber.yield
        end

        def sync_cb fiber
          Proc.new do |*args|
            if fiber == Fiber.current
              return *args
            else
              fiber.resume *args
            end
          end
        end

        %w[connect start run].each do |type|
          module_eval %[
            def #{type}(*params)
              sync { |f| ::AMQP.#{type}(*params, &sync_cb(f)) }
            end
          ]
        end
      end

      class Channel < ::AMQP::Channel
        def initialize(*params, &block)
          f = Fiber.current
          super(*params, &EM::Synchrony::AMQP.sync_cb(f))
          Fiber.yield
        end

        %w[direct fanout topic headers queue queue! flow prefetch recover tx_select tx_commit tx_rollback reset]
        .each do |type|
          module_eval %[
            alias :a#{type} :#{type}
            def #{type}(*params)
              EM::Synchrony::AMQP.sync { |f| self.a#{type}(*params, &EM::Synchrony::AMQP.sync_cb(f)) }
            end
          ]
        end
      end

      class Exchange < ::AMQP::Exchange
        def initialize(channel, type, name, opts = {}, &block)
          f = Fiber.current
          super(channel, type, name, opts, &EM::Synchrony::AMQP.sync_cb(f))
          Fiber.yield
        end

        %w[publish delete]
        .each do |type|
          module_eval %[
            alias :a#{type} :#{type}
            def #{type}(*params)
              EM::Synchrony::AMQP.sync { |f| self.a#{type}(*params, &EM::Synchrony::AMQP.sync_cb(f)) }
            end
          ]
        end
      end

      class Queue < ::AMQP::Queue
        def initialize(*params)
          f = Fiber.current
          super(*params, &EM::Synchrony::AMQP.sync_cb(f))
          Fiber.yield
        end

        alias :asubscribe :subscribe
        def subscribe &block
          Fiber.new do
            asubscribe(&EM::Synchrony::AMQP.sync_cb(Fiber.current))
            loop { block.call(Fiber.yield) }
          end.resume
        end

        %w[bind rebind unbind delete purge pop unsubscribe status]
        .each do |type|
          module_eval %[
            alias :a#{type} :#{type}
            def #{type}(*params)
              EM::Synchrony::AMQP.sync { |f| self.a#{type}(*params, &EM::Synchrony::AMQP.sync_cb(f)) }
            end
          ]
        end
      end

      class Session < ::AMQP::Session
        %w[disconnect].each do |type|
          module_eval %[
            alias :a#{type} :#{type}
            def #{type}(*params)
              EM::Synchrony::AMQP.sync { |f| self.a#{type}(*params, &EM::Synchrony::AMQP.sync_cb(f)) }
            end
          ]
        end
      end

    end
  end
end
