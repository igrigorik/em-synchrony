require "spec/helper/all"

describe EventMachine::Synchrony do

  it "should execute one-shot timer in Fiber" do
    EM.synchrony do
      start = Time.now.to_f

      EM::Synchrony.add_timer(0.1) do
        EM::Synchrony.sleep(0.1)

        (Time.now.to_f - start).should > 0.2
        EventMachine.stop
      end
    end
  end

  it "should execute period timers in Fibers" do
    EM.synchrony do
      start = Time.now.to_f
      num = 0

      EM::Synchrony.add_periodic_timer(0.1) do
        EM::Synchrony.sleep(0.1)
        num += 1

        if num > 1
          (Time.now.to_f - start).should > 0.3
          EventMachine.stop
        end
      end
    end
  end

end
