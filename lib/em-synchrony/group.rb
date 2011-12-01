require 'em-synchrony/event'
module EM::Synchrony
  class Group
    def initialize
      @finish_cond = EM::Synchrony::Event.new
      @unfinished = 0
    end

    def add
      @unfinished += 1
    end

    def done
      @unfinished -= 1
      if @unfinished == 0
        @finish_cond.set
      elsif @unfinished < 0
        raise "Too many done for #{self}"
      end
    end

    def with(&blk)
      add
      proc do |*args, &ablk|
        blk.call(*args, &ablk)
        done
      end
    end

    def wait
      unless @unfinished == 0
        @finish_cond.wait
      end
    end
  end
end