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

    context "when defferable succeeded before adding" do
      it "does not succeed twice" do
        multi = EM::Synchrony::Multi.new
        multi.should_receive(:succeed).once

        slow = EM::DefaultDeferrable.new
        multi.add :slow, slow

        quick = EM::DefaultDeferrable.new
        quick.succeed
        multi.add :quick, quick

        slow.succeed
      end
    end
  end
end
