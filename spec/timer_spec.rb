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
  describe '#add_locked_periodic_timer' do
    let(:executor) { ->{ } }
    let(:timer) { 0.1 }
    around do |example|
      EM.synchrony do
        EM::Synchrony.add_locked_periodic_timer(timer, &executor)
        example.run
        EM.cancel_timer(executor)
        EM.stop
      end
    end
    it 'should execute locked timers only once' do
      sleep = 0.5
      called = 0
      expect(executor).to receive(:call) do
        called += 1
        EM::Synchrony.sleep(sleep)
      end
      EM::Synchrony.sleep(sleep - timer)
      expect(called).to eq 1
      EM::Synchrony.sleep(timer * 3)
      expect(called).to eq 2
    end
    it 'should allow double add' do
      expect { EM::Synchrony.add_locked_periodic_timer(timer, &executor) }
        .not_to raise_error
    end
    context 'with two timers' do
      let(:executor2) { ->{ } }
      around do |example|
        EM::Synchrony.add_locked_periodic_timer(timer, &executor2)
        example.run
        EM.cancel_timer(executor2)
      end
      it 'should run both timers independently' do
        sleep1 = 0.5
        sleep_diff = 0.4
        sleep2 = sleep1 + sleep_diff
        called1 = 0
        called2 = 0
        expect(executor).to receive(:call) do
          called1 += 1
          EM::Synchrony.sleep(sleep1)
        end
        expect(executor2).to receive(:call) do
          called2 += 1
          EM::Synchrony.sleep(sleep2)
        end
        EM::Synchrony.sleep(sleep1 - timer)
        expect(called1).to eq 1
        expect(called2).to eq 1
        EM::Synchrony.sleep(timer + (sleep_diff / 2))
        expect(called1).to eq 2
        expect(called2).to eq 1
        EM::Synchrony.sleep((timer * 2) + (sleep_diff / 2))
        expect(called1).to eq 2
        expect(called2).to eq 2
      end
    end
  end

  it 'should return instance of EventMachine::Timer from add_timer method' do
    EM.synchrony do
      timer = EM::Synchrony.add_timer(0.1){}
      timer.should be_instance_of(EventMachine::Timer)
      EventMachine.stop
    end
  end
end
