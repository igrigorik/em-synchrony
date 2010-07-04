require "spec/helper/all"
require "em-synchrony/iterator"

describe EventMachine::Synchrony do

  URL = "http://localhost:8081/"
  DELAY = 0.01

  it "should allow inline callbacks for Deferrable object" do
    EM.synchrony do
      s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", DELAY)

      result = EM::Synchrony.sync EventMachine::HttpRequest.new(URL).aget
      result.response.should match(/Foo/)

      EM.stop
    end
  end

  it "should inline errback/callback cases" do
    EM.synchrony do
      class E
        include EventMachine::Deferrable
        def run
          EM.add_timer(0.01) {fail("uh oh!")}
          self
        end
      end

      result = EM::Synchrony.sync E.new.run
      result.should match(/uh oh!/)

      EM.stop
    end
  end

end
