require "spec/helper/all"

describe EM::Hiredis do

  it "should connect on demand" do
    EventMachine.synchrony do
      connection = EM::Hiredis::Client.connect
      connection.should_not be_connected

      connection.ping
      connection.should be_connected

      EventMachine.stop
    end
  end

  it "should work with compact connect syntax" do
    EventMachine.synchrony do
      redis = EM::Hiredis.connect

      redis.set('a', 'bar')
      redis.get('a').should == 'bar'

      EM.stop
    end
  end

  it "should work with manual db select" do
    EventMachine.synchrony do
      redis = EM::Hiredis.connect 'redis://127.0.0.1:6379'
      redis.select(0)

      redis.set('a', 'baz')
      redis.get('a').should == 'baz'

      EM.stop
    end
  end

  it "should get/set records synchronously" do
    EventMachine.synchrony do
      redis = EM::Hiredis::Client.connect

      redis.set('a', 'foo')
      redis.get('a').should == 'foo'
      redis.get('c').should == nil

      EM.stop
    end
  end

  it "should incr/decr key synchronously" do
    EventMachine.synchrony do
      redis = EM::Hiredis::Client.connect
      redis.del('key')

      redis.incr('key')
      redis.get('key').to_i.should == 1

      redis.decr('key')
      redis.get('key').to_i.should == 0

      EM.stop
    end
  end
end
