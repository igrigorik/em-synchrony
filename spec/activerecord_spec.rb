require "spec/helper/all"
require "em-synchrony/activerecord"

# create database widgets;
# use widgets;
# create table widgets (idx INT);

class Widget < ActiveRecord::Base; end;

describe "Fiberized ActiveRecord driver for mysql2" do
  DELAY = 0.25
  QUERY = "SELECT sleep(#{DELAY})"

  it "should establish AR connection" do
    EventMachine.synchrony do
      ActiveRecord::Base.establish_connection(
        :adapter => 'em_mysql2',
        :database => 'widgets',
        :username => 'root'
      )

      result = Widget.find_by_sql(QUERY)
      result.size.should == 1

      EventMachine.stop
    end
  end

  it "should fire sequential, synchronous requests within single fiber" do
    EventMachine.synchrony do
      ActiveRecord::Base.establish_connection(
        :adapter => 'em_mysql2',
        :database => 'widgets',
        :username => 'root'
      )

      start = now
      res = []

      res.push Widget.find_by_sql(QUERY)
      res.push Widget.find_by_sql(QUERY)

      (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)
      res.size.should == 2

      EventMachine.stop
    end
  end

end