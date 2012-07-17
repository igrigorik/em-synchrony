require "spec/mongoid/mongoid_helper"

describe Mongoid do

  describe "pooling" do
    it "should use the pool arguments" do
      EM.synchrony do
        Mongoid.from_hash({"host"=> "localhost", "database"=> "test", "pool_size"=>5})   
        sd = SimpleDocument.first
        sd = SimpleDocument.first
        sd = SimpleDocument.first
        sd = SimpleDocument.first
        sd = SimpleDocument.first
        EventMachine.stop
      end
      
    end
  end

  describe "a plain document" do
    it "should save" do
      EM.synchrony do
        Mongoid.from_hash({"host"=> "localhost", "database"=> "test"})
        sd = SimpleDocument.new(name: "test1", counter: 1)
        sd.save.should == true
        
        EventMachine.stop
      end
    end
  end

end