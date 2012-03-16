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
          it "should resume in nested Fiber" do
            EM.synchrony do
              f = Fiber.new do
                m.synchronize do
                  t = m.sleep(0.05)
                  t.should >= 0.05
                end
                EM.stop
              end
              f.resume
            end
          end
        end
      end
    end
  end
  describe EventMachine::Synchrony::Thread::ConditionVariable do
    let(:c){ EM::Synchrony::Thread::ConditionVariable.new }
    it "should wakeup waiter" do
      i = ''
      EM.synchrony do
        f1 = Fiber.new do
          m.synchronize do
            i << 'a'
            c.wait(m)
            i << 'c'
          end
          EM.stop
        end.resume
        f2 = Fiber.new do
          i << 'b'
          c.signal
        end.resume
      end
      i.should == 'abc'
    end
    it 'should allow to play ping-pong' do
      i = ''
      EM.synchrony do
        f1 = Fiber.new do
          m.synchronize do
            i << 'pi'
            c.wait(m)
            i << '-po'
            c.signal
          end
        end.resume
        f2 = Fiber.new do
          m.synchronize do
            i << 'ng'
            c.signal
            c.wait(m)
            i << 'ng'
          end
          EM.stop
        end.resume
      end
      i.should == 'ping-pong'
    end
    it 'should not raise, when timer wakes up fiber between `signal` and `next_tick`' do
      proc {
        EM.synchrony do
          f = Fiber.new do
            m.synchronize do
              c.wait(m, 0.0001)
            end
            EM.add_timer(0.001){ EM.stop }
          end
          i = 0
          f.resume
          EM.next_tick{
            c.signal
          }
        end
      }.should_not raise_error
    end
  end
end
