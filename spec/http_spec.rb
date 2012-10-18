require "spec/helper/all"

URL = "http://localhost:8081/"
CONNECTION_ERROR_URL = "http://random-domain-blah.com/"
DELAY = 0.25

describe EventMachine::HttpRequest do
  it "should perform a synchronous fetch" do
    EM.synchrony do
      s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", DELAY)

      r = EventMachine::HttpRequest.new(URL).get
      r.response.should == 'Foo'

      s.stop
      EventMachine.stop
    end
  end

  it "should fire sequential requests" do
    EventMachine.synchrony do
      s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", DELAY)

      start = now
      order = []
      order.push :get  if EventMachine::HttpRequest.new(URL).get
      order.push :post if EventMachine::HttpRequest.new(URL).post
      order.push :head if EventMachine::HttpRequest.new(URL).head
      order.push :post if EventMachine::HttpRequest.new(URL).delete
      order.push :put  if EventMachine::HttpRequest.new(URL).put
      order.push :options if EventMachine::HttpRequest.new(URL).options
      order.push :patch  if EventMachine::HttpRequest.new(URL).patch

      (now - start.to_f).should be_within(DELAY * order.size * 0.15).of(DELAY * order.size)
      order.should == [:get, :post, :head, :post, :put, :options, :patch]

      s.stop
      EventMachine.stop
    end
  end

  it "should fire simultaneous requests via Multi interface" do
    EventMachine.synchrony do
      s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", DELAY)

      start = now

      multi = EventMachine::Synchrony::Multi.new
      multi.add :a, EventMachine::HttpRequest.new(URL).aget
      multi.add :b, EventMachine::HttpRequest.new(URL).apost
      multi.add :c, EventMachine::HttpRequest.new(URL).ahead
      multi.add :d, EventMachine::HttpRequest.new(URL).adelete
      multi.add :e, EventMachine::HttpRequest.new(URL).aput
      multi.add :f, EventMachine::HttpRequest.new(URL).aoptions
      multi.add :g, EventMachine::HttpRequest.new(URL).apatch
      res = multi.perform

      (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
      res.responses[:callback].size.should == 7
      res.responses[:errback].size.should == 0

      s.stop
      EventMachine.stop
    end
  end

  it "should terminate immediately in case of connection errors" do
    EventMachine.synchrony do
      response = EventMachine::HttpRequest.new(CONNECTION_ERROR_URL, :connection_timeout => 0.1).get
      response.error.should_not be_nil

      EventMachine.stop
    end
  end

  it "should process inactivity timeout correctly" do
    EventMachine.synchrony do
      s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", 5)

      start = now
      r = EventMachine::HttpRequest.new(URL, :inactivity_timeout => 0.1).get
      (now - start.to_f).should be_within(0.2).of(0.1)

      s.stop
      EventMachine.stop
    end
  end
end
