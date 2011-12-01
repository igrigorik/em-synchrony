require 'em-synchrony/event'
require 'em-synchrony/group'
require 'active_support/callbacks'
module EM::Synchrony
  class Queue    
    class Empty < StandardError; end

    include ActiveSupport::Callbacks

    define_callbacks :pop, :push

    attr_reader :queue, :waiters
    def initialize
      @queue = []
      @waiters = []
    end

    def push(obj)
      run_callbacks :push do
        if waiters.present?
          waiters.shift.resume obj
        else
          queue << obj
        end
      end
    end
    alias :<< :push

    def pop(non_block = false)
      run_callbacks :pop do
        if queue.size > 0
          queue.shift
        elsif non_block
          raise Empty.new
        else
          waiters << Fiber.current
          Fiber.yield
        end
      end
    end
  end

  class JoinableQueue < Queue
    define_callbacks :task_done
    set_callback :push, :before, :inc_unfinished_tasks
    def initialize
      super
      @group = EM::Synchrony::Group.new
    end

    def task_done
      run_callbacks :task_done do
        @group.done
      end
    end

    def join
      @group.wait
    end

    private

    def inc_unfinished_tasks
      @group.add
    end
  end
end