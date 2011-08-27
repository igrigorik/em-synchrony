# EM-Synchrony

Collection of convenience classes and primitives to help untangle evented code, plus a number of patched EM clients to make them Fiber aware. To learn more, please see: [Untangling Evented Code with Ruby Fibers](http://www.igvita.com/2010/03/22/untangling-evented-code-with-ruby-fibers).

 * Fiber aware ConnectionPool with sync/async query support
 * Fiber aware Iterator to allow concurrency control & mixing of sync / async
 * Fiber aware async inline support: turns any async function into sync
 * Fiber aware Multi-request interface for any callback enabled clients
 * Fiber aware TCPSocket replacement, powered by EventMachine
 * Fiber aware Thread, Mutex, ConditionVariable clases
 * Fiber aware sleep

Supported clients:

 * [mysql2](http://github.com/igrigorik/em-synchrony/blob/master/spec/mysql2_spec.rb): .query is synchronous, while .aquery is async (see specs)
 * [activerecord](http://github.com/igrigorik/em-synchrony/blob/master/spec/activerecord_spec.rb): require synchrony/activerecord, set your AR adapter to em_mysql2 and you should be good to go
 * [em-http-request](http://github.com/igrigorik/em-synchrony/blob/master/spec/http_spec.rb): .get, etc are synchronous, while .aget, etc are async
 * [em-memcached](http://github.com/igrigorik/em-synchrony/blob/master/spec/memcache_spec.rb) & [remcached](http://github.com/igrigorik/em-synchrony/blob/master/spec/remcached_spec.rb): .get, etc, and .multi_* methods are synchronous
 * [em-mongo](http://github.com/igrigorik/em-synchrony/blob/master/spec/em-mongo_spec.rb): .find, .first are synchronous
 * [mongoid](http://github.com/igrigorik/em-synchrony/blob/master/spec/mongo_spec.rb): all functions synchronous, plus Rails compatibility
 * em-jack: a[method]'s are async, and all regular jack method's are synchronous

Other clients with native Fiber support:

 * redis: contains [synchrony code](https://github.com/ezmobius/redis-rb/blob/master/test/synchrony_driver.rb) right within the driver
 * synchrony also supports [em-redis](http://github.com/igrigorik/em-synchrony/blob/master/spec/redis_spec.rb) and em-hiredis (see specs), but unless you specifically need either of those, use the official redis gem

## Fiber-aware Iterator: mixing sync / async code

Allows you to perform each, map, inject on a collection of any asynchronous tasks. To advance the iterator, simply call iter.next, or iter.return(result). The iterator will not exit until you advance through the entire collection. Additionally, you can specify the desired concurrency level! Ex: crawling a web-site, but you want to have at most 5 connections open at any one time.

```ruby
require "em-synchrony"
require "em-synchrony/em-http"

EM.synchrony do
    concurrency = 2
    urls = ['http://url.1.com', 'http://url2.com']

    # iterator will execute async blocks until completion, .each, .inject also work!
    results = EM::Synchrony::Iterator.new(urls, concurrency).map do |url, iter|

        # fire async requests, on completion advance the iterator
        http = EventMachine::HttpRequest.new(url).aget
        http.callback { iter.return(http) }
        http.errback { iter.return(http) }
    end

    p results # all completed requests
    EventMachine.stop
end
```

Or, you can use FiberIterator to hide the async nature of em-http:

```ruby
require "em-synchrony"
require "em-synchrony/em-http"

EM.synchrony do
    concurrency = 2
    urls = ['http://url.1.com', 'http://url2.com']
    results = []

    EM::Synchrony::FiberIterator.new(urls, concurrency).each do |url|
        resp = EventMachine::HttpRequest.new(url).get
    results.push resp.response
    end

    p results # all completed requests
    EventMachine.stop
end
```

## Fiber-aware ConnectionPool shared by a fiber:
Allows you to create a pool of resources which are then shared by one or more fibers. A good example is a collection of long-lived database connections. The pool will automatically block and wake up the fibers as the connections become available.

```ruby
require "em-synchrony"
require "em-synchrony/mysql2"

EventMachine.synchrony do
    db = EventMachine::Synchrony::ConnectionPool.new(size: 2) do
        Mysql2::EM::Client.new
    end

    multi = EventMachine::Synchrony::Multi.new
    multi.add :a, db.aquery("select sleep(1)")
    multi.add :b, db.aquery("select sleep(1)")
    res = multi.perform

    p "Look ma, no callbacks, and parallel MySQL requests!"
    p res

    EventMachine.stop
end
```

## Fiber-aware Multi interface: parallel HTTP requests
Allows you to fire simultaneous requests and wait for all of them to complete (success or error) before advancing. Concurrently fetching many HTTP pages at once is a good example; parallel SQL queries is another. Technically, this functionality can be also achieved by using the Synchrony Iterator shown above.

```ruby
require "em-synchrony"
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
```

## Fiber-aware & EventMachine backed TCPSocket:
This is dangerous territory - you've been warned. You can patch your base TCPSocket class to make any/all libraries depending on TCPSocket be actually powered by EventMachine and Fibers under the hood.

```ruby
require "em-synchrony"
require "lib/em-synchrony"
require "net/http"

EM.synchrony do
  # replace default Socket code to use EventMachine Sockets instead
  TCPSocket = EventMachine::Synchrony::TCPSocket

  Net::HTTP.get_print 'www.google.com', '/index.html'
  EM.stop
end
```

## Inline synchronization & Fiber sleep:
Allows you to inline/synchronize any callback interface to behave as if it was a blocking call. Simply pass any callback object to Synchrony.sync and it will do the right thing: the fiber will be resumed once the callback/errback fires. Likewise, use Synchrony.sleep to avoid blocking the main thread if you need to put one of your workers to sleep.

```ruby
require "em-synchrony"
require "em-synchrony/em-http"
EM.synchrony do
  # pass a callback enabled client to sync to automatically resume it when callback fires
  result = EM::Synchrony.sync EventMachine::HttpRequest.new('http://www.gooogle.com/').aget
  p result

  # pause exection for 2 seconds
  EM::Synchrony.sleep(2)

  EM.stop
end
```

## Async ActiveRecord:

Allows you to use async ActiveRecord within Rails and outside of Rails (see [async-rails](https://github.com/igrigorik/async-rails)). If you need to control the connection pool size, use [rack/fiber_pool](https://github.com/mperham/rack-fiber_pool/).

```ruby
require "em-synchrony"
require "em-synchrony/activerecord"

ActiveRecord::Base.establish_connection(
  :adapter => 'em_mysql2',
  :database => 'widgets'
)

result = Widget.all.to_a
```

# License

The MIT License - Copyright (c) 2011 Ilya Grigorik