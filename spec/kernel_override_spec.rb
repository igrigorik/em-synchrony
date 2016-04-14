# encoding: UTF-8
require 'spec/helper/all'

describe EventMachine::Synchrony do
  before do
    EM::Synchrony.on_sleep
  end
  after do
    EM::Synchrony.on_sleep
  end
  describe '#sleep' do
    context 'outside synchrony' do
      it 'does not call hook' do
        EM::Synchrony.on_sleep { fail 'should not happen' }
        expect { sleep(0.01) }.not_to raise_error
      end

      it 'works when calling with no arguments' do
        t = Thread.new do
          expect { sleep }.to_not raise_error
        end
        while t.status
          if t.status == 'sleep'
            t.run
          end
        end
        t.join
      end
      context 'with synchrony in another thread'do
        before do
          @thread = Thread.new do
            EM.run do
              sleep(0.5)
              EM.stop
            end
          end
          sleep(0.1)
        end
        after do
          @thread.join
        end
        it 'does not call hook' do
          EM::Synchrony.on_sleep { fail 'should not happen' }
          expect { sleep(0.01) }.not_to raise_error
        end
      end
    end

    context 'within synchrony' do
      around do |example|
        EM.synchrony do
          example.run
          EM.next_tick { EM.stop }
        end
      end
      context 'with no hook defined' do
        it 'calls Kernel.sleep' do
          expect(self).to receive(:sleep)
          sleep(1)
        end
      end
      context 'with hook defined' do
        it 'executes the hook' do
          called = 0
          EM::Synchrony.on_sleep { called += 1 }
          (1..10).each do |count|
            sleep(1)
            expect(called).to be count
          end
        end
        it 'propagates exceptions' do
          msg = 'expected exception'
          EM::Synchrony.on_sleep { fail msg }
          expect { sleep(1) }.to raise_error(RuntimeError, msg)
        end
        context "when calling 'sleep' in the hook" do
          it 'calls the original sleep' do
            sleep_time = 1.213234123412341454134512345
            expect(self).to receive(:orig_sleep).with(sleep_time)
            EM::Synchrony.on_sleep do |*args|
              sleep(*args)
            end
            sleep(sleep_time)
          end
        end
      end

    end
  end
end
