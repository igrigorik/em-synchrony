require "spec/helper/all"
require "em-synchrony/fiber_iterator"

describe EventMachine::Synchrony::FiberIterator do

  it "should wait until the iterator is done and wrap internal block within a fiber" do
    EM.synchrony do

      results = []
      i = EM::Synchrony::FiberIterator.new(1..5, 2).each do |num|
        EM::Synchrony.sleep(0.1)
        results.push num
      end

      results.should == (1..5).to_a
      results.size.should == 5
      EventMachine.stop
    end
  end

  #
  # it "should sum values within the iterator" do
  #   EM.synchrony do
  #     data = (1..5).to_a
  #     res = EM::Synchrony::FiberIterator.new(data, 2).inject(0) do |total, num, iter|
  #       EM::Synchrony.sleep(0.1)
  #
  #       p [:sync, total, num]
  #       iter.return(total += num)
  #     end
  #
  #     res.should == data.inject(:+)
  #     EventMachine.stop
  #   end
  # end



end
