module EventMachine
  class HttpRequest

    alias :aget :get
    def get options = {}, &blk
      f = Fiber.current

      conn = setup_request(:get, options, &blk)
      conn.callback { f.resume(conn) }
      conn.errback  { f.resume(conn) }

      Fiber.yield
    end

    alias :ahead :head
    def head options = {}, &blk
      f = Fiber.current

      conn = setup_request(:head, options, &blk)
      conn.callback { f.resume(conn) }
      conn.errback  { f.resume(conn) }

      Fiber.yield
    end

    alias :adelete :delete
    def delete options = {}, &blk
      f = Fiber.current

      conn = setup_request(:delete, options, &blk)
      conn.callback { f.resume(conn) }
      conn.errback  { f.resume(conn) }

      Fiber.yield
    end
    
    alias :aput :put
    def put options = {}, &blk
      f = Fiber.current

      conn = setup_request(:put, options, &blk)
      conn.callback { f.resume(conn) }
      conn.errback  { f.resume(conn) }

      Fiber.yield
    end
    
    alias :apost :post
    def post options = {}, &blk
      f = Fiber.current

      conn = setup_request(:post, options, &blk)
      conn.callback { f.resume(conn) }
      conn.errback  { f.resume(conn) }

      Fiber.yield
    end

  end
end
