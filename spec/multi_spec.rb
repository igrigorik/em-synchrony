require "helper/all"

describe EM::Synchrony do
  describe "Multi" do
    it "should require unique keys for each deferrable" do
      lambda do
        m = EM::Synchrony::Multi.new
        m.add :df1, EM::DefaultDeferrable.new
        m.add :df1, EM::DefaultDeferrable.new
      end.should raise_error("Duplicate Multi key")
    end
  end
end