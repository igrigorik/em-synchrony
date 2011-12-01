require "spec/helper/all"
require "em-synchrony/fibered_activerecord"
require "em-synchrony/group"

# create database widgets;
# use widgets;
# create table widgets (
# id INT NOT NULL AUTO_INCREMENT,
# title varchar(255),
# PRIMARY KEY (`id`)
# );
describe "Fiberized ActiveRecord driver for mysql2" do
  class Widget < ActiveRecord::Base; end;

  DELAY = 0.25
  QUERY = "SELECT sleep(#{DELAY})"

  def establish_connection
      ActiveRecord::Base.establish_connection(
        :adapter => 'fibered_mysql2',
        :database => 'widgets',
        :username => 'root',
        :pool => 1,
        :real_pool => 10
      )
  end

  it "should establish AR connection" do
    EventMachine.synchrony do
      establish_connection

      result = Widget.find_by_sql(QUERY)
      result.size.should eql(1)
      EventMachine.stop
    end
  end

  it "should fire sequential, synchronous requests within single fiber" do
    EventMachine.synchrony do
      establish_connection

      start = now
      res = []

      res.push Widget.find_by_sql(QUERY)
      res.push Widget.find_by_sql(QUERY)

      (now - start.to_f).should be_within(DELAY * res.size * 0.15).of(DELAY * res.size)
      res.size.should eql(2)

      EventMachine.stop
    end
  end

  it "should fire 100 parallel requests in fibers" do
    EM.synchrony do
      establish_connection
      g = EM::Synchrony::Group.new
      100.times do        
        Fiber.new(&g.with do
          Widget.find_by_sql(QUERY)
        end).resume
      end
      g.wait
      EM.stop
    end
  end

  it "should create widget" do
    EM.synchrony do
      establish_connection
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE widgets;")
      Widget.create
      Widget.create
      Widget.count.should eql(2)
      EM.stop
    end
  end

  it "should update widget" do
    EM.synchrony do
      establish_connection
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE widgets;")
      widget = Widget.create title: 'hi'
      widget.update_attributes title: 'hello'
      Widget.find(widget.id).title.should eql('hello')
      EM.stop
    end
  end

end