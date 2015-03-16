require "spec/helper/all"

describe EventMachine::Synchrony do

  it "system: simple" do
    EM.synchrony do
      out, status = EM::Synchrony.system("echo 'some'")

      status.should == 0
      out.should == "some\n"

      EM.stop
    end
  end
end
