require "helper/all"

describe EM::Synchrony, "#sync" do
  it "returns immediately if the syncee already succeeded" do
    args = stub("args")
    
    Fiber.new {
      df = EM::DefaultDeferrable.new
      df.succeed args
      
      EM::Synchrony.sync(df).should == args
    }.resume
  end
end
