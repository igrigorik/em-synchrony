require 'spec/helper'

URL = "http://localhost:8081/"
DELAY = 0.25

def now(); Time.now.to_f; end

describe EventMachine::HttpRequest do
  it "should fire sequential requests" do
    EventMachine.run do
      @s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", DELAY)

      Fiber.new {
        start = now
        order = []
        order.push :get  if EventMachine::HttpRequest.new(URL).get
        order.push :post if EventMachine::HttpRequest.new(URL).post
        order.push :head if EventMachine::HttpRequest.new(URL).head
        order.push :post if EventMachine::HttpRequest.new(URL).delete
        order.push :put  if EventMachine::HttpRequest.new(URL).put

        (now - start.to_f).should be_within(DELAY * order.size * 0.15).of(DELAY * order.size)
        order.should == [:get, :post, :head, :post, :put]

        EventMachine.stop
      }.resume
    end
  end

  it "should fire simultaneous requests via Multi interface" do
    EventMachine.run do
      @s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", DELAY)

      Fiber.new {
        start = now

        multi = EventMachine::Multi.new
        multi.add EventMachine::HttpRequest.new(URL).aget
        multi.add EventMachine::HttpRequest.new(URL).apost
        multi.add EventMachine::HttpRequest.new(URL).ahead
        multi.add EventMachine::HttpRequest.new(URL).adelete
        multi.add EventMachine::HttpRequest.new(URL).aput
        res = multi.perform
        
        (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
        res.responses[:callback].size.should == 5
        res.responses[:errback].size.should == 0

        EventMachine.stop
      }.resume
    end
  end
end
