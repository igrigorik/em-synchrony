require "spec/helper/all"
require "tempfile"

DELAY = 0.1

describe EventMachine::Synchrony do
  before(:each) { @temp_file = Tempfile.new("stdout") }
  after(:each) { @temp_file.unlink }
  
  def with_input(string = "", &block)
    string = "#{string}\n"
    
    @temp_file.write string
    @temp_file.flush
    
    EM::Synchrony.add_timer(DELAY) do
      original_stdin = STDIN
      STDIN.reopen(@temp_file.path)
          
      block.call if block_given?
          
      STDIN.reopen(original_stdin)
    end
  end

  it "waits for input" do
    EM.synchrony do
      start = now
      
      with_input do
        EM::Synchrony.gets
        
        (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
      end
      
      EM.add_timer(DELAY * 2) { EM.stop }
    end
  end
  
  it "trails input with a newline to emulate gets" do
    EM.synchrony do
      with_input("Hello") do
        EM::Synchrony.gets.should == "Hello\n"
      end
      
      EM.add_timer(DELAY * 2) { EM.stop }
    end
  end
  
  it "should stop after the first line" do
    EM.synchrony do
      with_input("Hello\nWorld!") do
        EM::Synchrony.gets.should == "Hello\n"
      end
      
      EM.add_timer(DELAY * 2) { EM.stop }
    end
  end
end
