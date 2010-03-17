require "spec/helper/all"
require "remcached"

describe Memcached do

  it "should yield until connection is ready" do
    EventMachine.run do
      Fiber.new {
        Memcached.connect %w(localhost)
        Memcached.usable?.should be_true
        EventMachine.stop
      }.resume
    end
  end

  it "should fire sequential memcached requests" do
    EventMachine.run do
      Fiber.new {

        Memcached.connect %w(localhost)
        Memcached.get(key: 'hai') do |res|
          res[:value].should match('Not found')
        end

        Memcached.set(key: 'hai', value: 'win')
        Memcached.add(key: 'count')
        Memcached.delete(key: 'hai')           
        
        EventMachine.stop
      }.resume
    end
  end

end
