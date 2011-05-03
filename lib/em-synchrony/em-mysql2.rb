begin
  require 'mysql2/em'
rescue LoadError => e
  raise "Missing mysql2 gem, add it to your Gemfile"
end

module Mysql2
  module EM
    class Client
      alias :aquery :query

      def query(*args)
        f = Fiber.current

        defer = aquery(*args)
        defer.callback { |result| f.resume(result) }
        defer.errback  { |result| f.resume(result) }

        final = Fiber.yield
        raise final if Mysql2::Error == final.class
        final
      end
    end
  end
end
