require "spec/helper/all"

describe EM::Hiredis do

  it "should yield until connection is ready" do
    EventMachine.synchrony do
      connection = EM::Hiredis::Client.connect
      connection.connected.should be_true

      EventMachine.stop
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
      redis.delete('key')

      redis.incr('key')
      redis.get('key').to_i.should == 1

      redis.decr('key')
      redis.get('key').to_i.should == 0

      EM.stop
    end
  end
end
