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

      #
      # The upcoming versions of EM-Mongo change Collection#find's interface: it
      # now returns a deferrable cursor YAY. This breaks compatibility with past
      # versions BOO. We'll just choose based on the presence/absence of
      # EM::Mongo::Cursor YAY
      #

      #
      # em-mongo version > 0.3.6
      #
      if defined?(EM::Mongo::Cursor)

        # afind     is the old (async) find
        # afind_one is rewritten to call afind
        # find      is sync, using a callback on the cursor
        # find_one  is sync, by calling find and taking the first element.
        # first     is sync, an alias for find_one

        alias :afind :find
        def find(*args)
          f = Fiber.current
          cursor = afind(*args)
          cursor.to_a.callback{ |res| f.resume(res) }
          Fiber.yield
        end

        # need to rewrite afind_one manually, as it calls 'find' (reasonably
        # expecting it to be what is now known as 'afind')

        def afind_one(spec_or_object_id=nil, opts={})
          spec = case spec_or_object_id
                 when nil
                   {}
                 when BSON::ObjectId
                   {:_id => spec_or_object_id}
                 when Hash
                   spec_or_object_id
                 else
                   raise TypeError, "spec_or_object_id must be an instance of ObjectId or Hash, or nil"
                 end
          afind(spec, opts.merge(:limit => -1)).next_document
        end
        alias :afirst :afind_one

        def find_one(selector={}, opts={})
          opts[:limit] = 1
          find(selector, opts).first
        end
        alias :first :find_one

      #
      # em-mongo version <= 0.3.6
      #
      else

        alias :afind :find
        def find(selector={}, opts={})

          f = Fiber.current
          cb = proc { |res| f.resume(res) }

          skip  = opts.delete(:skip) || 0
          limit = opts.delete(:limit) || 0
          order = opts.delete(:order)

          @connection.find(@name, skip, limit, order, selector, nil, &cb)
          Fiber.yield
        end

        # need to rewrite afirst manually, as it calls 'find' (reasonably
        # expecting it to be what is now known as 'afind')

        def afirst(selector={}, opts={}, &blk)
          opts[:limit] = 1
          afind(selector, opts) do |res|
            yield res.first
          end
        end

        def first(selector={}, opts={})
          opts[:limit] = 1
          find(selector, opts).first
        end
      end

    end

  end
end
