require "spec/helper/all"
require "mysqlplus"
require "em-mysqlplus"

DELAY = 0.25
QUERY = "select sleep(#{DELAY})"

describe EventMachine::MySQL do

  it "should fire sequential, synchronous requests" do
    EventMachine.synchrony do
      db = EventMachine::MySQL.new(host: "localhost")
      start = now
      res = []

      res.push db.query(QUERY)
      res.push db.query(QUERY)
      (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)

      EventMachine.stop
    end
  end

  it "should have accept a callback, errback on async queries" do
    EventMachine.synchrony do
      db = EventMachine::MySQL.new(host: "localhost")

      res = db.aquery(QUERY)
      res.errback {|r| fail }
      res.callback {|r|
        r.all_hashes.size.should == 1
        EventMachine.stop
      }
    end
  end

  it "should fire simultaneous requests via Multi interface" do
    EventMachine.synchrony do

      db = EventMachine::Synchrony::ConnectionPool.new(size: 2) do
        EventMachine::MySQL.new(host: "localhost")
      end

      start = now

      multi = EventMachine::Synchrony::Multi.new
      multi.add :a, db.aquery(QUERY)
      multi.add :b, db.aquery(QUERY)
      res = multi.perform

      (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
      res.responses[:callback].size.should == 2
      res.responses[:errback].size.should == 0

      EventMachine.stop
    end
  end

  it "should fire sequential and simultaneous MySQL requests" do
    EventMachine.synchrony do
      db = EventMachine::Synchrony::ConnectionPool.new(size: 3) do
        EventMachine::MySQL.new(host: "localhost")
      end

      start = now
      res = []

      res.push db.query(QUERY)
      res.push db.query(QUERY)
      (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)

      start = now

      multi = EventMachine::Synchrony::Multi.new
      multi.add :a, db.aquery(QUERY)
      multi.add :b, db.aquery(QUERY)
      multi.add :c, db.aquery(QUERY)
      res = multi.perform

      (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
      res.responses[:callback].size.should == 3
      res.responses[:errback].size.should == 0

      EventMachine.stop
    end
  end

  it "should raise Mysql::Error in case of error" do
    EventMachine.synchrony do
      db = EventMachine::MySQL.new(host: "localhost")
      proc {
        db.query("SELECT * FROM i_hope_this_table_does_not_exist;")
      }.should raise_error(Mysql::Error)
      EventMachine.stop
    end
  end

end
