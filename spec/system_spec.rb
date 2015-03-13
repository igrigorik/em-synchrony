require "spec/helper/all"

describe EventMachine::Synchrony do

  # FIXME: Not only it fails on Travis for some reason, but it also
  # triggers failures in many of the examples that run after it.
  it "system: simple", ci_skip: true do
    EM.synchrony do
      out, status = EM::Synchrony.system("echo 'some'")

      status.should == 0
      out.should == "some\n"

      EM.stop
    end
  end
end
