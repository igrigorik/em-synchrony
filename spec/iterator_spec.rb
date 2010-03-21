require "spec/helper/all"
require "em-synchrony/iterator"

describe EventMachine::Synchrony::Iterator do

  it "should wait until the iterator is done" do
    EM.synchrony do

      results = []
      i = EM::Synchrony::Iterator.new(1..50, 10).each do |num, iter|
        results.push num
        iter.next
      end

      results.should == (1..50).to_a
      results.size.should == 50
      EventMachine.stop
    end
  end

  it "should map values within the iterator" do
    EM.synchrony do
      results = EM::Synchrony::Iterator.new(1..50, 10).map do |num, iter|
        iter.return(num + 1)
      end

      results.should == (2..51).to_a
      results.size.should == 50
      EventMachine.stop
    end
  end

  it "should sum values within the iterator" do
    EM.synchrony do
      data = (1..50).to_a
      res = EM::Synchrony::Iterator.new(data, 10).inject(0) do |total, num, iter|
        total += num
        iter.return(total)
      end

      res.should == data.inject(:+)
      EventMachine.stop
    end
  end

  it "should fire async http requests in blocks of 2" do
    EM.synchrony do
      num_urls = 4
      concurrency = 2
      delay = 0.25
      
      s = StubServer.new("HTTP/1.0 200 OK\r\nConnection: close\r\n\r\nFoo", delay)
      urls = ['http://localhost:8081/'] * num_urls
      
      start = now
      results = EM::Synchrony::Iterator.new(urls, concurrency).map do |url, iter|
        http = EventMachine::HttpRequest.new(url).aget
        http.callback { iter.return(http) }
      end

      results.size.should == 4
      (now - start.to_f).should be_within(delay * 0.15).of(delay * (num_urls / concurrency))
      
      EventMachine.stop
    end
  end

end
