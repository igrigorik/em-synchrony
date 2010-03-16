require "spec/helper/all"
require 'em-mysqlplus'
DELAY = 0.25
QUERY = "select sleep(#{DELAY})"

describe EventMachine::MySQL do

  it "should fire sequential, synchronous requests" do
    EventMachine.run do
      Fiber.new {
        db = EventMachine::MySQL.new(:host => "localhost")
        start = now
        res = []

        res.push db.query(QUERY)
        res.push db.query(QUERY)
        (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)

        EventMachine.stop
      }.resume
    end
  end

  it "should have accept a callback, errback on async queries" do
    EventMachine.run do
      db = EventMachine::MySQL.new(:host => "localhost")

      res = db.aquery(QUERY)
      res.errback {|r| fail }
      res.callback {|r|
        r.all_hashes.size.should == 1
        EventMachine.stop
      }
    end
  end

  it "should fire simultaneous requests via Multi interface" do
    EventMachine.run do

      # TODO: need pooling logic
      db = EventMachine::MySQL.new(:host => "localhost")

      Fiber.new {
        start = now

        multi = EventMachine::Multi.new
        multi.add db.aquery(QUERY)
        multi.add db.aquery(QUERY)
        res = multi.perform

        (now - start.to_f).should be_within(DELAY * 2 * 0.15).of(DELAY)
        p res
        res.responses[:callback].size.should == 2
        res.responses[:errback].size.should == 0

        EventMachine.stop
      }.resume
    end
  end

  it "should fire sequential and simultaneous MySQL requests" do
    EventMachine.run do
      db = EventMachine::MySQL.new(:host => 'localhost')

      Fiber.new {
        start = now
        res = []

        res.push db.query(QUERY)
        res.push db.query(QUERY)
        (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)

        start = now

        # TODO: need pooling logic
        multi = EventMachine::Multi.new
        multi.add db.aquery(QUERY)
        multi.add db.aquery(QUERY)
        multi.add db.aquery(QUERY)
        res = multi.perform

        (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
        res.responses[:callback].size.should == 3
        res.responses[:errback].size.should == 0

        EventMachine.stop
      }.resume
    end
  end

end