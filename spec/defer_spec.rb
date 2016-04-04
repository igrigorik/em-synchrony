require "spec/helper/all"

describe EventMachine::Synchrony do

  it "defer: simple" do
    EM.synchrony do
      x = 1
    
      result = EM::Synchrony.defer do
        x = 2
        sleep 0.1
        3
      end
      
      result.should == 3      
      x.should == 2
      
      EM.stop    
    end
  end
  
  it "defer: with lambda" do
    EM.synchrony do
    
      x = 1
      
      op = lambda do
        sleep 0.1
        x += 1
        3
      end
      
      EM::S.defer(op).should == 3
      x.should == 2
              
      EM.stop
    end                                                  
  end
  
end
