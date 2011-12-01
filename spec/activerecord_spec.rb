require "spec/helper/all"
require "em-synchrony/activerecord"
require "em-synchrony/group"

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

  it "should fire 100 parallel requests in fibers" do
    EM.synchrony do
      ActiveRecord::Base.establish_connection(
        :adapter => 'em_mysql2',
        :database => 'widgets',
        :username => 'root'
      )
      g = EM::Synchrony::Group.new
      100.times do        
        Fiber.new(&g.with do
          Widget.find_by_sql(QUERY)
        end).resume
      end
      g.wait
      ActiveRecord::Base.connection_pool.connections.size.should eql(5)
      EM.stop

    end
  end

end