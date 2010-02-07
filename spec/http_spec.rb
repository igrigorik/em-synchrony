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
        order.push :get if EventMachine::HttpRequest.new(URL).get
        order.push :post if EventMachine::HttpRequest.new(URL).post
        order.push :head if EventMachine::HttpRequest.new(URL).head
        order.push :post if EventMachine::HttpRequest.new(URL).post
        order.push :put if EventMachine::HttpRequest.new(URL).put

        (now - start.to_f).should be_within(DELAY * 5 * 0.15).of(DELAY * 5)
        order.should == [:get, :post, :head, :post, :put]
        
        EventMachine.stop
      }.resume
    end
  end
end

# describe EventMachine::Multi do
#
#   it "should fire simultaneous requests" do
#
#     EventMachine.run do
#       @s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo")
#
#       Fiber.new {
#
#         http = EventMachine::HttpRequest.new(URL).get
#         http = EventMachine::HttpRequest.new(URL).get
#
#         puts "Done"
#         EventMachine.stop
#
#       }.resume
#     end
#   end
# end
