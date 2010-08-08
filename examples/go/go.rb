require 'em-synchrony'

module Kernel
  def go(*args, &blk)
    EM.next_tick do
      Fiber.new { blk.call(*args) }.resume
    end
  end
end

class Channel < EM::Queue
  def initialize(opts = {})
    @limit = opts[:size]
    @prodq = []
    @size  = 0

    super()
  end

  def size; @size; end
  def empty?; size == 0; end

  def pop
    f = Fiber.current
    clb = Proc.new do |*args|
      @size -= 1
      f.resume(args)
      @prodq.shift.call if !@prodq.empty?
    end

    super(&clb)
    Fiber.yield
  end

  def push(*items)
    f = Fiber.current
    @size += 1

    EM.next_tick { super(*items) }

    # if the queue is bounded, then suspend the producer
    # until someone consumes a pending message
    if @limit && size >= @limit
      @prodq.push -> { f.resume }
      Fiber.yield
    end
  end
  alias :<< :push
end
