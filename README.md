# EM-Synchrony

Blog post: [Untangling Evented Code with Ruby Fibers](http://www.igvita.com/2010/03/22/untangling-evented-code-with-ruby-fibers)

Collection of convenience classes and patches to common EventMachine clients to
make them Fiber aware and friendly. Word of warning: even though fibers have been
backported to Ruby 1.8.x, these classes assume Ruby 1.9 (if you're using fibers
in production, you should be on 1.9 anyway)

Features:

 * Fiber aware connection pool with sync/async query support
 * Multi request interface which accepts any callback enabled client
 * Fibered iterator to allow concurrency control & mixing of sync / async
 * em-http-request: .get, etc are synchronous, while .aget, etc are async
 * em-mysqlplus: .query is synchronous, while .aquery is async
 * remcached: .get, etc, and .multi_* methods are synchronous
 * bitly v2 and v3: synchronous api calls with EM::HttpRequest.

## Example with async em-http client:
    require "em-synchrony/em-http"
    EventMachine.synchrony do
        res = EventMachine::HttpRequest.new("http://www.postrank.com").get
        p "Look ma, no callbacks!"
        p res

        EventMachine.stop
    end

## EM Iterator & mixing sync / async code

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

## Example connection pool shared by a fiber:

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

## Example with multi-request async em-http client:

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