require "spec/helper/all"
require "remcached"

describe Memcached do

  it "should yield until connection is ready" do
    EventMachine.synchrony do
      Memcached.connect %w(localhost)
      Memcached.usable?.should be_true
      EventMachine.stop
    end
  end

  it "should fire sequential memcached requests" do
    EventMachine.synchrony do

      Memcached.connect %w(localhost)
      Memcached.get(key: 'hai') do |res|
        res[:value].should match('Not found')
      end

      Memcached.set(key: 'hai', value: 'win')
      Memcached.add(key: 'count')
      Memcached.delete(key: 'hai')

      EventMachine.stop
    end
  end

  it "should fire multi memcached requests" do
    EventMachine.synchrony do
      pending "patch mult-get"

      Memcached.connect %w(localhost)
      Memcached.multi_get([{:key => 'foo'},{:key => 'bar'}, {:key => 'test'}]) do |res|
        # TODO
        EventMachine.stop
      end
    end
  end

end
