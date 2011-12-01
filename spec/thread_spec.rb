require "spec/helper/all"

describe EventMachine::Synchrony::Mutex do
  let(:m) { EM::Synchrony::Mutex.new }
  it "should synchronize" do
    EM.synchrony do
      i = 0
      f1 = Fiber.new do
        m.synchronize do
          f = Fiber.current
          EM.next_tick { f.resume }
          Fiber.yield
          i += 1
        end
      end.resume
      f1 = Fiber.new do
        m.synchronize do
          i.should eql(1)
          EM.stop
        end
      end.resume
    end
  end

  describe "lock" do
    describe "when mutex already locked" do

      it "should raise ThreadError" do
        f = Fiber.new do
          m.lock
          Fiber.yield
          m.lock
        end
        f.resume
        proc { f.resume }.should raise_error(FiberError)
      end
    end
  end

  describe "sleep" do
  # TODO: release lock
    describe "without timeout" do
      it "should sleep until resume" do
        EM.synchrony do
          m.lock
          i = 0
          f = Fiber.current
          EM.next_tick { i += 1; f.resume }
          res = m.sleep
          i.should eql(1)
          EM.stop
        end
      end

      it "should release lock" do
        EM.synchrony do
          i = 0
          Fiber.new do 
            m.lock
            f = Fiber.current
            EM.next_tick { f.resume }
            Fiber.yield
            i += 1
            m.sleep
          end.resume
          Fiber.new do 
            m.lock
            i.should eql(1)
            EM.stop
          end.resume
        end
      end

      it "should wait unlock after resume" do
        EM.synchrony do
          i = 0
          f1 = Fiber.new do 
            m.lock
            m.sleep
            i.should eql(1)
            EM.stop
          end
          f2 = Fiber.new do 
            m.lock
            f1.resume
            i += 1
            m.unlock
          end
          f1.resume
          f2.resume
        end
      end
      describe "with timeout" do
        it "should sleep for timeout" do
          EM.synchrony do
            m.lock
            i = 0
            EM.next_tick { i += 1 }
            m.sleep(0.05)
            i.should eql(1)
            EM.stop
          end
        end
        describe "and resume before timeout" do
          it "should not raise any execptions" do
            EM.synchrony do
              m.lock
              f = Fiber.current
              EM.next_tick { f.resume }
              m.sleep(0.05)
              EM.add_timer(0.1) { EM.stop }
            end
          end
        end
      end
    end
  end
end

describe EventMachine::Synchrony::ConditionVariable do
  let(:m) { EM::Synchrony::Mutex.new }
  let(:cond_var) { EM::Synchrony::ConditionVariable.new }
  describe "signal" do
    it "should wait signal" do
      EM.synchrony do
        i = 0
        EM.next_tick do 
          i += 1
          cond_var.signal
        end
        Fiber.new do
          m.synchronize do
            cond_var.wait m
          end
          i.should eql(1)
          EM.stop
        end.resume
      end
    end

    it "should resume only one fiber" do
      EM.synchrony do
        f1 = Fiber.new do
          m.synchronize do
            cond_var.wait m
          end
        end
        f2 = Fiber.new do 
          m.synchronize do
            cond_var.wait m
          end
        end        
        f1.resume
        f2.resume
        cond_var.signal
        f1.alive?.should be_false
        f2.alive?.should be_true
        cond_var.signal
        f1.alive?.should be_false
        f2.alive?.should be_false
        EM.stop
      end
    end
  end

  describe "broadcast" do
    it "should resume all fibers" do
      EM.synchrony do
        f1 = Fiber.new do 
          m.synchronize do
            cond_var.wait m
          end
        end
        f2 = Fiber.new do 
          m.synchronize do
            cond_var.wait m
          end
        end
        f1.resume; f2.resume
        cond_var.broadcast
        f1.alive?.should be_false
        f2.alive?.should be_false
        EM.stop
      end
    end
  end
end

describe EventMachine::Synchrony::MonitorMixin do
  let(:buf) { [].tap { |o| o.extend(EM::Synchrony::MonitorMixin) }}
  let(:cond) { buf.new_cond }

  it "should synchronize fibers" do
    EM.synchrony do
      Fiber.new do
        while EM.reactor_running?
          buf.synchronize do
            cond.wait_while { buf.empty? }
            size = buf.size
            EM::Synchrony.wait_next_tick
            buf.size.should eql(size)
          end
        end
      end.resume

      Fiber.new do
        [:foo, :bar, :zoo].each do |v|
          buf.synchronize do
            buf.push v
            cond.signal
          end
        end
        EM.stop
      end.resume
    end
  end
end