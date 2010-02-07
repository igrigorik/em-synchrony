require 'spec/helper'

DELAY = 0.25

describe EMJack do

  it "should fire sequential Beanstalk requests" do
    EventMachine.run do

      Fiber.new {
        jack = EMJack::Connection.new

        r = jack.use('mytube')
        r.should == 'mytube'

        EventMachine.stop
      }.resume
    end
  end

  it "should fire multiple requests in parallel" do
    EventMachine.run do

      Fiber.new {
        jack = EMJack::Connection.new

        multi = EventMachine::Multi.new
        multi.add jack.ause('mytube-1')
        multi.add jack.ause('mytube-2')
        res = multi.perform
        
        res.responses.size.should == 2
        p [:multi, res.responses]
        
        EventMachine.stop
      }.resume

    end
  end
  
end
