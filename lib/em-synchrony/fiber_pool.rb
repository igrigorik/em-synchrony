# Author::    Mohammad A. Ali  (mailto:oldmoe@gmail.com)
# Copyright:: Copyright (c) 2008 eSpace, Inc.
# License::   Distributes under the same terms as Ruby
module EM::Synchrony

  class FiberPool

    # gives access to the currently free fibers
    attr_reader :fibers
    attr_reader :busy_fibers

    # Code can register a proc with this FiberPool to be called
    # every time a Fiber is finished.  Good for releasing resources
    # like ActiveRecord database connections.
    attr_accessor :generic_callbacks

    # Prepare a list of fibers that are able to run different blocks of code
    # every time. Once a fiber is done with its block, it attempts to fetch
    # another one from the queue
    def initialize(count = 100)
      @fibers,@busy_fibers,@queue,@generic_callbacks = [],{},[],[]
      count.times do |i|
        fiber = Fiber.new do |block, args|
          loop do
            block.call(*args)
            # callbacks are called in a reverse order, much like c++ destructor
            Fiber.current[:callbacks].pop.call while Fiber.current[:callbacks].length > 0
            generic_callbacks.each do |cb|
              cb.call
            end
            unless @queue.empty?
              block, args = @queue.shift
            else
              @busy_fibers.delete(Fiber.current.object_id)
              @fibers.unshift Fiber.current
              block, args = Fiber.yield
            end
          end
        end
        fiber[:callbacks] = []
        fiber[:em_keys] = []
        @fibers << fiber
      end
    end

    # If there is an available fiber use it, otherwise, leave it to linger
    # in a queue
    def spawn(*args, &block)
      if fiber = @fibers.shift
        fiber[:callbacks] = []
        @busy_fibers[fiber.object_id] = fiber
        fiber.resume(block, args)
      else
        @queue << [block, args]
      end
      self # we are keen on hiding our queue
    end

    # Wait all tasks in pool
    def waitall
      unless @busy_fibers.empty? && @queue.empty?
        f = Fiber.current
        clb = proc do
          if @queue.empty? && @busy_fibers.size == 1 # 1 - just finished fiber
            f.resume
          end
        end
        generic_callbacks << clb
        Fiber.yield
        generic_callbacks.delete clb
      end
    end

    # Execute block in fiber pool and wait result
    def execute(&blk)
      e = EM::Synchrony::Event.new
      spawn do
        e.set blk.call
      end
      e.wait
    end

    # Iterate through enumerable, execute each in pool, and wait their completion.
    def iterate(enumerable, &blk)
      g = EM::Synchrony::Group.new
      f = Fiber.current
      enumerable.each do |val|
        if fibers.size > 0
          spawn(val, &g.with(&blk))
        else
          spawn do
            f.resume val
          end
          val = Fiber.yield
          spawn(val, &g.with(&blk))
        end
      end
      g.wait
    end

    def iterate_each(enumerable, &blk)
      iterate(enumerable) { |rows| rows.each(&blk) }
    end

  end
end