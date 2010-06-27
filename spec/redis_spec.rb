require "spec/helper/all"

describe EM::Protocols::Redis do

  it "should yield until connection is ready" do
    EventMachine.synchrony do
      connection = EM::Protocols::Redis.connect
      connection.connected.should be_true

      EventMachine.stop
    end
  end

  it "should get/set records synchronously" do
    EventMachine.synchrony do
      redis = EM::Protocols::Redis.connect

      redis.set('a', 'foo')
      redis.get('a').should == 'foo'
      redis.get('c').should == nil

      EM.stop
    end
  end

  it "should incr/decr key synchronously" do
    EventMachine.synchrony do
      redis = EM::Protocols::Redis.connect
      redis.delete('key')

      redis.incr('key')
      redis.get('key').to_i.should == 1

      redis.decr('key')
      redis.get('key').to_i.should == 0

      EM.stop
    end
  end

  it "should execute async commands" do
    EventMachine.synchrony do
      redis = EM::Protocols::Redis.connect
      redis.set('a', 'foobar')
      redis.aget('a') do |response|
        response.should == 'foobar'
        EM.stop
      end
    end
  end

  it "should execute async set add" do
    EventMachine.synchrony do
      redis = EM::Protocols::Redis.connect

      redis.asadd('test', 'hai') do
        redis.asadd('test', 'bai') do
          redis.aset_count('test') do |resp|
            resp.to_i.should == 2
            EM.stop
          end
        end
      end
    end
  end
end