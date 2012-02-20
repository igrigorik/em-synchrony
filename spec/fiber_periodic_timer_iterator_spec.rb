require "spec/helper/all"
require "em-synchrony/fiber_periodic_timer_iterator"

describe EventMachine::Synchrony::FiberPeriodicTimerIterator do

  it "should execute 4 blocks in 3 seconds" do
    results = []
    EM.synchrony do
      EM::Synchrony::FiberPeriodicTimerIterator.new(1..4, 10, 1).each(nil, proc{EventMachine.stop}) do |num|
        results << Time.now
      end
    end
    (results.last - results.first).round.should == 3
  end

  # 7 blocks each executes for 3 seconds
  # concurrency is 4
  # timeout is 0.5 second
  # total time should be 11 seconds
  it "should execute 7 blocks with long time execution in 7 seconds" do
    results = []
    results << Time.now
    EM.synchrony do
      EM::Synchrony::FiberPeriodicTimerIterator.new(1..7, 4, 0.5).each(nil, proc{EventMachine.stop}) do |num|
        EM::Synchrony.sleep(3)
        results << Time.now
      end
    end
    (results.last - results.first).round.should == 7
  end

end
