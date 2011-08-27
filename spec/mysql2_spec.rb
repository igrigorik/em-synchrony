require "spec/helper/all"
require "em-synchrony/mysql2"

describe Mysql2::EM::Client do

  DELAY = 0.25
  QUERY = "SELECT sleep(#{DELAY}) as mysql2_query"

  it "should support queries" do
    res = []
    EventMachine.synchrony do
      db = Mysql2::EM::Client.new
      res = db.query QUERY

      EventMachine.stop
    end

    res.first.keys.should include("mysql2_query")
  end

  it "should fire sequential, synchronous requests" do
    EventMachine.synchrony do
      db = Mysql2::EM::Client.new

      start = now
      res = []

      res.push db.query QUERY
      res.push db.query QUERY
      (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)

      EventMachine.stop
    end
  end

  it "should have accept a callback, errback on async queries" do
    EventMachine.synchrony do
      db = Mysql2::EM::Client.new

      res = db.aquery(QUERY)
      res.errback {|r| fail }
      res.callback {|r|
        r.size.should == 1
        EventMachine.stop
      }
    end
  end

  it "should fire simultaneous requests via Multi interface" do
    EventMachine.synchrony do

      db = EventMachine::Synchrony::ConnectionPool.new(size: 2) do
        Mysql2::EM::Client.new
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
        Mysql2::EM::Client.new
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
      db = Mysql2::EM::Client.new
      proc {
        db.query("SELECT * FROM i_hope_this_table_does_not_exist;")
      }.should raise_error(Mysql2::Error)
      EventMachine.stop
    end
  end

end
