begin
  require 'mysql2/em'
rescue LoadError => error
  raise 'Missing EM-Synchrony dependency: gem install mysql2'
end

module Mysql2
  module EM
    class Client
      module Watcher
        def notify_readable
          detach
          begin
            result = @client.async_result
          rescue Exception => e
            @deferable.fail(e)
          else
            @deferable.succeed(result)
          end
        end
      end

      alias :aquery :query
      def query(sql, opts={})
        deferable = aquery(sql, opts)

        # if EM is not running, we just get the sql result directly
        # if we get a deferable, then let's do the deferable thing.
        return deferable unless deferable.kind_of? ::EM::DefaultDeferrable

        f = Fiber.current
        deferable.callback { |res| f.resume(res) }
        deferable.errback  { |err| f.resume(err) }

        Fiber.yield.tap do |result|
          raise result if result.is_a?(::Exception)
        end
      end
    end
  end
end
