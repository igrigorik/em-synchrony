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
  
  it "should fire multi memcached requests" do
    pending "remcached borked? opened a ticket"
    
    EventMachine.run do
      Fiber.new {

        Memcached.connect %w(localhost)
        
        Memcached.multi_get([{:key => 'foo'},{:key => 'bar'}, {:key => 'test'}]) do |res|
          p res
        end
                
        EventMachine.stop
      }.resume
    end
  end

end
