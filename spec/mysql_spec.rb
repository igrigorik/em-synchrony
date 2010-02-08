require 'spec/helper'

DELAY = 0.25
QUERY = "select sleep(#{DELAY})"

describe EventMachine::MySQL do

  it "should fire sequential and simultaneous MySQL requests" do
    EventMachine.run do
      @db = EventMachine::MySQL.new(:connections => 5)

      Fiber.new {
        start = now
        res = []

        res.push @db.select(QUERY)
        res.push @db.select(QUERY)
        (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)

        start = now

        multi = EventMachine::Multi.new
        multi.add @db.aselect(QUERY)
        multi.add @db.aselect(QUERY)
        multi.add @db.aselect(QUERY)
        res = multi.perform

        (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
        res.responses[:callback].size.should == 3
        res.responses[:errback].size.should == 0

        EventMachine.stop
      }.resume
    end
  end

  # Erm? Why does the mixed case get all screwy?

  it "should fire sequential requests" do
    EventMachine.run do
      Fiber.new {
        @db = EventMachine::MySQL.new
        start = now
        res = []

        res.push @db.select(QUERY)
        res.push @db.select(QUERY)
        (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)

        EventMachine.stop
      }.resume
    end
  end

  it "should have accept a callback, errback" do
    EventMachine.run do
      @db = EventMachine::MySQL.new

      res = @db.aselect(QUERY)
      res.errback {|r| fail }
      res.callback {|r|
        r.size.should == 1
        EventMachine.stop
      }
    end
  end

  it "should fire simultaneous requests via Multi interface" do

    EventMachine.run do
      @db = EventMachine::MySQL.new(:connections => 2)

      Fiber.new {
        start = now

        multi = EventMachine::Multi.new
        multi.add @db.aselect(QUERY)
        multi.add @db.aselect(QUERY)
        res = multi.perform

        (now - start.to_f).should be_within(DELAY * 2 * 0.15).of(DELAY)
        res.responses[:callback].size.should == 2
        res.responses[:errback].size.should == 0

        EventMachine.stop
      }.resume
    end
  end

end
