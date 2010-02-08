require 'spec/helper'

describe Memcached do

  it "should fire sequential memcached requests" do
    EventMachine.run do
      Fiber.new {


        Memcached.connect(%w(127.0.0.1:11211))
        p Memcached.usable?

        # p Memcached.set({:key => 'hai', :value => 'win'})
        # p Memcached.set(:key => 'Hello', :value => 'Planet')
        p Memcached.get(:key => 'hai')

        EventMachine.stop
      }.resume
    end
  end

  # it "should fire multiple requests in parallel" do
  #    pending
  #
  #    EventMachine.run do
  #
  #      Fiber.new {
  #        jack = EMJack::Connection.new
  #
  #        multi = EventMachine::Multi.new
  #        multi.add jack.ause('mytube-1')
  #        multi.add jack.ause('mytube-2')
  #        res = multi.perform
  #
  #        res.responses.size.should == 2
  #        p [:multi, res.responses]
  #
  #        EventMachine.stop
  #      }.resume
  #
  #    end
  #  end

end
