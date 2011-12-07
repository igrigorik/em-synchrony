require "spec/helper/all"

describe EventMachine::Synchrony::Thread::Mutex do
  let(:m) { EM::Synchrony::Thread::Mutex.new }
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