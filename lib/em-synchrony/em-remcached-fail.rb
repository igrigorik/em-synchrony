# There are a number of em-memcache libraries:
# - http://github.com/astro/remcached/ -- Most feature complete, up-to-date: binary protocol, etc.
#   * http://code.google.com/p/memcached/wiki/MemcacheBinaryProtocol
#   * http://code.sixapart.com/svn/memcached/trunk/server/doc/protocol.txt
#
# - http://github.com/cliffmoon/eventedcache/ -- Older, but good specs + ragel parser for the protocol.
#

require 'remcached'

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

    alias :aoperation :operation
    def operation(request_klass, contents, &blk)
      f = Fiber.current
      cb = Proc.new {|r| f.resume(r)}

      client = client_for_key(contents[:key])
      p [client, contents, blk]
      if client
        client.send_request request_klass.new(contents), &cb
      else
        return {:status => Errors::DISCONNECTED}
      end

      Fiber.yield
    end

  end
end
