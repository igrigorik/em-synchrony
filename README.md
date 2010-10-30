# EM-Synchrony

Collection of convenience classes and primitives to help untangle evented code, plus a number of patched EM clients to make them Fiber aware. To learn more, please see: [Untangling Evented Code with Ruby Fibers](http://www.igvita.com/2010/03/22/untangling-evented-code-with-ruby-fibers). Word of warning: even though Fibers have been backported to Ruby 1.8.x, these classes assume Ruby 1.9.x (if you're using fibers in production, you should be on 1.9.x anyway).

 * Fiber aware connection pool with sync/async query support
 * Fiber aware iterator to allow concurrency control & mixing of sync / async
 * Fiber aware async inline support: turns any async function into sync
 * Fiber aware multi-request interface for any callback enabled clients
 * Fiber aware TCPSocket replacement, powered by EventMachine
 * Fiber aware Thread, Mutex, ConditionVariable clases
 * Fiber aware sleep

Supported clients:

 * em-http-request: .get, etc are synchronous, while .aget, etc are async
 * em-memcached & remcached: .get, etc, and .multi_* methods are synchronous
 * em-redis: synchronous connect, .a{cmd} are async
 * em-mysqlplus: .query is synchronous, while .aquery is async
 * em-mongo: .find, .first are synchronous
 * mongoid: all functions synchronous, plus Rails compatability
 * bitly v2 and v3: synchronous api calls with EM::HttpRequest.


## Fiber-aware Iterator: mixing sync / async code
Allows you to perform each, map, inject on a collection of any asynchronous tasks. To advance the iterator, simply call iter.next, or iter.return(result). The iterator will not exit until you advance through the entire collection. Additionally, you can specify the desired concurrency level! Ex: crawling a web-site, but you want to have at most 5 connections open at any one time.

    require "em-synchrony/em-http"
    EM.synchrony do
        concurrency = 2
        urls = ['http://url.1.com', 'http://url2.com']

        # iterator will execute async blocks until completion, .each, .inject also work!
        results = EM::Synchrony::Iterator.new(urls, concurrency).map do |url, iter|

            # fire async requests, on completion advance the iterator
            http = EventMachine::HttpRequest.new(url).aget
            http.callback { iter.return(http) }
        end

        p results # all completed requests
        EventMachine.stop
    end

## Fiber-aware ConnectionPool shared by a fiber:
Allows you to create a pool of resources which are then shared by one or more fibers. A good example is a collection of long-lived database connections. The pool will automatically block and wake up the fibers as the connections become available.

    require "em-synchrony/em-mysqlplus"
    EventMachine.synchrony do
        db = EventMachine::Synchrony::ConnectionPool.new(size: 2) do
            EventMachine::MySQL.new(host: "localhost")
        end

        multi = EventMachine::Synchrony::Multi.new
        multi.add :a, db.aquery("select sleep(1)")
        multi.add :b, db.aquery("select sleep(1)")
        res = multi.perform

        p "Look ma, no callbacks, and parallel MySQL requests!"
        p res

        EventMachine.stop
    end

## Fiber-aware Multi inteface: parallel HTTP requests
Allows you to fire simultaneous requests and wait for all of them to complete (success or error) before advancing. Concurrently fetching many HTTP pages at once is a good example; parallel SQL queries is another. Technically, this functionality can be also achieved by using the Synchrony Iterator shown above.

    require "em-synchrony/em-http"
    EventMachine.synchrony do
        multi = EventMachine::Synchrony::Multi.new
        multi.add :a, EventMachine::HttpRequest.new("http://www.postrank.com").aget
        multi.add :b, EventMachine::HttpRequest.new("http://www.postrank.com").apost
        res = multi.perform

        p "Look ma, no callbacks, and parallel HTTP requests!"
        p res

        EventMachine.stop
    end

## Fiber-aware & EventMachine backed TCPSocket:
This is dangerous territory - you've been warned. You can patch your base TCPSocket class to make any/all libraries depending on TCPSocket be actually powered by EventMachine and Fibers under the hood.

    require "lib/em-synchrony"
    require "net/http"

    EM.synchrony do
      # replace default Socket code to use EventMachine Sockets instead
      TCPSocket = EventMachine::Synchrony::TCPSocket

      Net::HTTP.get_print 'www.google.com', '/index.html'
      EM.stop
    end

## Inline synchronization & Fiber sleep:
Allows you to inline/synchronize any callback interface to behave as if it was a blocking call. Simply pass any callback object to Synchrony.sync and it will do the right thing: the fiber will be resumed once the callback/errback fires. Likewise, use Synchrony.sleep to avoid blocking the main thread if you need to put one of your workers to sleep.

    EM.synchrony do
      # pass a callback enabled client to sync to automatically resume it when callback fires
      result = EM::Synchrony.sync EventMachine::HttpRequest.new('http://www.gooogle.com/').aget
      p result

      # pause exection for 2 seconds
      EM::Synchrony.sleep(2)

      EM.stop
    end

## Patched clients

EM-Synchrony ships with a number of patched Eventmachine clients, which allow you to patch your asynchronous drivers on the fly to behave as if they were actually blocking clients:

 * [em-http-request](http://github.com/igrigorik/em-synchrony/blob/master/spec/http_spec.rb)
 * [em-mysqlplus](http://github.com/igrigorik/em-synchrony/blob/master/spec/mysqlplus_spec.rb)
 * [em-redis](http://github.com/igrigorik/em-synchrony/blob/master/spec/redis_spec.rb)
 * [em-memcached](http://github.com/igrigorik/em-synchrony/blob/master/spec/memcache_spec.rb) & [remcached](http://github.com/igrigorik/em-synchrony/blob/master/spec/remcached_spec.rb)
 * [em-mongo](http://github.com/igrigorik/em-synchrony/blob/master/spec/em-mongo_spec.rb) & [mongoid](http://github.com/igrigorik/em-synchrony/blob/master/spec/mongo_spec.rb)

# License

(The MIT License)

Copyright (c) 2010 Ilya Grigorik

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
