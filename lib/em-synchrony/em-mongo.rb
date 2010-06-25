begin
  require "em-mongo"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install em-mongo"
end

module EM
  module Mongo

    class Connection
      def initialize(host = DEFAULT_IP, port = DEFAULT_PORT, timeout = nil, opts = {})
        f = Fiber.current

        @em_connection = EMConnection.connect(host, port, timeout, opts)
        @db = {}

        # establish connection before returning
        EM.next_tick { f.resume }
        Fiber.yield
      end
    end

    class Collection

      alias :afind :find
      def find(selector={}, opts={})

        f = Fiber.current
        cb = proc { |res| f.resume(res) }

        skip  = opts.delete(:skip) || 0
        limit = opts.delete(:limit) || 0

        @connection.find(@name, skip, limit, selector, nil, &cb)
        Fiber.yield
      end

      alias :afirst :first
      def first(selector={}, opts={})
        opts[:limit] = 1
        find(selector, opts).first
      end
    end

  end
end
