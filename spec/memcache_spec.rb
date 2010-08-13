require "spec/helper/all"

describe EM::P::Memcache do

  it "should fire sequential memcached requests" do
    EventMachine.synchrony do
      conn = EM::P::Memcache.connect
      key = 'key'
      value = 'value for key'
      fake_key = 'nonexistent key' # without a corresponding value

      conn.delete(key)
      conn.set(key, value)
      conn.get(key).should == value

      conn.delete(key)
      conn.get(key).should be_nil

      conn.set(key, value)
      conn.get(key).should == value

      conn.del(key)
      conn.get(key).should be_nil

      conn.set(key, value)
      conn.get(key, fake_key).should == [value, nil]
      conn.get_hash(key, fake_key).should == { key => value, fake_key => nil }

      EventMachine.stop
    end
  end

end
