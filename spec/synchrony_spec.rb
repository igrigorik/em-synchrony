require "helper/all"

describe EM::Synchrony do
  describe "#sync" do
    it "returns immediately if the syncee already succeeded" do
      args = stub("args")

      Fiber.new {
        df = EM::DefaultDeferrable.new
        df.succeed args
        EM::Synchrony.sync(df).should == args

        df = EM::DefaultDeferrable.new
        df.succeed nil
        EM::Synchrony.sync(df).should == nil
      }.resume
    end
  end

  describe "#next_tick" do
    it "should wrap next_tick into a Fiber context" do
      EM.synchrony {
        begin
          fired = false
          f = Fiber.current

          EM::Synchrony.next_tick do
            fired = true
            Fiber.current.should_not eq(f)
          end

          EM::Synchrony.interrupt

          fired.should eq(true)
        ensure
          EM.stop
        end
      }
    end
  end

end
