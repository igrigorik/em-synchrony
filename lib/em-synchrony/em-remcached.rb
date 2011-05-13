begin
  require "remcached"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install remcached"
end

module Memcached
  class << self

    def connect(servers)
      Memcached.servers = servers

      f = Fiber.current
      @w = EM::Timer.new(10.0) { f.resume :error }
      @t = EM::PeriodicTimer.new(0.01) do
        if Memcached.usable?
          @w.cancel
          @t.cancel
          f.resume(self)
        end
      end

      r = Fiber.yield

      (r == :error) ? (raise Exception.new('Cannot connect to memcached server')) : r
    end

    %w[add get set delete].each do |type|
      class_eval %[
        def a#{type}(contents, &callback)
          df = EventMachine::DefaultDeferrable.new
          df.callback &callback

          cb = Proc.new { |res| df.succeed(res) }
          operation Request::#{type.capitalize}, contents, &cb

          df
        end

        def #{type}(contents, &callback)
          fiber = Fiber.current
          paused = false

          cb = Proc.new do |res|
            if paused
              fiber.resume(res)
            else
              return res
            end
          end

          df = a#{type}(contents, &cb)
          df.callback &callback

          paused = true
          Fiber.yield
        end
      ]
    end

    %w[add get set delete].each do |type|
      class_eval %[
        def amulti_#{type}(contents, &callback)
          df = EventMachine::DefaultDeferrable.new
          df.callback &callback

          cb = Proc.new { |res| df.succeed(res) }
          multi_operation Request::#{type.capitalize}, contents, &cb

          df
        end

        def multi_#{type}(contents, &callback)
          fiber = Fiber.current
          paused = false

          cb = Proc.new do |res|
            if paused
              fiber.resume(res)
            else
              return res
            end
          end

          df = amulti_#{type}(contents, &cb)
          df.callback &callback

          paused = true
          Fiber.yield
        end
      ]
    end

  end
end
