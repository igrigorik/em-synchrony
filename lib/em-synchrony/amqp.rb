begin
  require "amqp"
  require "amq/protocol"
rescue LoadError
  raise "Missing EM-Synchrony dependency: gem install amqp"
end

module EventMachine
  module Synchrony
    module AMQP
      class Error < RuntimeError; end

      class << self
        def sync &blk
          fiber = Fiber.current
          blk.call(fiber)
          Fiber.yield
        end

        def sync_cb fiber
          lambda do |*args|
            if fiber == Fiber.current
              return *args
            else
              fiber.resume(*args)
            end
          end
        end

        %w[connect start run].each do |type|
          line = __LINE__ + 2
          code = <<-EOF
            def #{type}(*params)
              sync { |f| ::AMQP.#{type}(*params, &sync_cb(f)) }
            end
          EOF
          module_eval(code, __FILE__, line)
        end
      end

      class Channel < ::AMQP::Channel
        def initialize(*params, &block)
          f = Fiber.current
          super(*params, &EM::Synchrony::AMQP.sync_cb(f))
          channel, open_ok = Fiber.yield
          raise Error.new unless open_ok.is_a?(::AMQ::Protocol::Channel::OpenOk)
          channel
        end

        %w[direct fanout topic headers].each do |type|
          line = __LINE__ + 2
          code = <<-EOF
            alias :a#{type} :#{type}
            def #{type}(name = 'amq.#{type}', opts = {})
              if exchange = find_exchange(name)
                extended_opts = Exchange.add_default_options(:#{type}, name, opts, nil)
                validate_parameters_match!(exchange, extended_opts, :exchange)
                exchange
              else
                register_exchange(Exchange.new(self, :#{type}, name, opts))
              end
            end
          EOF
          module_eval(code, __FILE__, line)
        end

        alias :aqueue! :queue!
        def queue!(name, opts = {})
          queue = Queue.new(self, name, opts)
          register_queue(queue)
        end

        %w[flow recover tx_select tx_commit tx_rollback reset]
        .each do |type|
          line = __LINE__ + 2
          code = <<-EOF
            alias :a#{type} :#{type}
            def #{type}(*params)
              EM::Synchrony::AMQP.sync { |f| self.a#{type}(*params, &EM::Synchrony::AMQP.sync_cb(f)) }
            end
          EOF
          module_eval(code, __FILE__, line)
        end
      end

      class Consumer < ::AMQP::Consumer
        alias :aon_delivery :on_delivery
        def on_delivery(&block)
          Fiber.new do
            aon_delivery(&EM::Synchrony::AMQP.sync_cb(Fiber.current))
            loop { block.call(Fiber.yield) }
          end.resume
          self
        end

        alias :aconsume :consume
        def consume(nowait = false)
          ret = EM::Synchrony::AMQP.sync { |f| self.aconsume(nowait, &EM::Synchrony::AMQP.sync_cb(f)) }
          raise Error.new(ret.to_s) unless ret.is_a?(::AMQ::Protocol::Basic::ConsumeOk)
          self
        end

        alias :aresubscribe :resubscribe
        def resubscribe
          EM::Synchrony::AMQP.sync { |f| self.aconsume(&EM::Synchrony::AMQP.sync_cb(f)) }
          self
        end

        alias :acancel :cancel
        def cancel(nowait = false)
          EM::Synchrony::AMQP.sync { |f| self.aconsume(nowait, &EM::Synchrony::AMQP.sync_cb(f)) }
          self
        end
      end

      class Exchange < ::AMQP::Exchange
        def initialize(channel, type, name, opts = {}, &block)
          f = Fiber.current

          # AMQP Exchange constructor handles certain special exchanges differently.
          # The callback passed in isn't called when the response comes back
          # but is called immediately on the original calling fiber. That means that
          # when the sync_cb callback yields the fiber when called, it will hang and never
          # be resumed.  So handle these exchanges without yielding
          if name == "amq.#{type}" or name.empty? or opts[:no_declare]
            exchange = nil
            super(channel, type, name, opts) { |ex| exchange = ex }
          else
            super(channel, type, name, opts, &EM::Synchrony::AMQP.sync_cb(f))
            exchange, declare_ok = Fiber.yield
            raise Error.new(declare_ok.to_s) unless declare_ok.is_a?(::AMQ::Protocol::Exchange::DeclareOk)
          end

          exchange
        end

        alias :apublish :publish
        def publish payload, options = {}
          apublish(payload, options)
        end

        alias :adelete :delete
        def delete(opts = {})
          EM::Synchrony::AMQP.sync { |f| adelete(opts, &EM::Synchrony::AMQP.sync_cb(f)) }
        end
      end

      class Queue < ::AMQP::Queue
        def initialize(*params)
          f = Fiber.current
          super(*params, &EM::Synchrony::AMQP.sync_cb(f))
          queue, declare_ok = Fiber.yield
          raise Error.new unless declare_ok.is_a?(::AMQ::Protocol::Queue::DeclareOk)
          queue
        end

        alias :asubscribe :subscribe
        def subscribe(opts = {}, &block)
          Fiber.new do
            asubscribe(opts, &EM::Synchrony::AMQP.sync_cb(Fiber.current))
            loop { block.call(Fiber.yield) }
          end.resume
        end

        %w[bind rebind unbind delete purge pop unsubscribe status].each do |type|
          line = __LINE__ + 2
          code = <<-EOF
            alias :a#{type} :#{type}
            def #{type}(*params)
              EM::Synchrony::AMQP.sync { |f| self.a#{type}(*params, &EM::Synchrony::AMQP.sync_cb(f)) }
            end
          EOF
          module_eval(code, __FILE__, line)
        end
      end

      class Session < ::AMQP::Session
        %w[disconnect].each do |type|
          line = __LINE__ + 2
          code = <<-EOF
            alias :a#{type} :#{type}
            def #{type}(*params)
              EM::Synchrony::AMQP.sync { |f| self.a#{type}(*params, &EM::Synchrony::AMQP.sync_cb(f)) }
            end
          EOF
          module_eval(code, __FILE__, line)
        end
      end
      ::AMQP.client = ::EM::Synchrony::AMQP::Session
    end
  end
end
