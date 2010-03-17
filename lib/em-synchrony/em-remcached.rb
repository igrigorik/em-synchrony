require "remcached"

module Memcached
  class << self

    def connect(servers)
      Memcached.servers = servers

      f = Fiber.current
      @t = EM::PeriodicTimer.new(0.01) do
        if Memcached.usable?
          @t.cancel
          f.resume(self)
        end
      end

      Fiber.yield
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
      
          df = a#{type}(contents, &Proc.new { |res| fiber.resume(res) })
          df.callback &callback
      
          Fiber.yield
        end
      ]
    end
    
    # def set(contents, &callback)
      # operation Request::Set, contents, &callback
    # end
    # def delete(contents, &callback)
      # operation Request::Delete, contents, &callback
    # end


  end
end
