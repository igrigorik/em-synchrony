require "em/iterator"

module EventMachine
  module Synchrony

    class Iterator < EM::Iterator

      # synchronous iterator which will wait until all the
      # jobs are done before returning. Unfortunately this
      # means that you loose ability to choose concurrency
      # on the fly (see iterator documentation in EM)
      def each(foreach=nil, after=nil, &blk)
        fiber = Fiber.current

        fe = (foreach || blk)
        cb = Proc.new do
          after.call if after
          fiber.resume
        end

        Fiber.yield super(fe, cb)
      end

      def map(&block)
        fiber = Fiber.current
        after = Proc.new {|result| p [:after_map, result]; fiber.resume(result)}
        
        Fiber.yield super(block, after)
      end

      def inject(obj, &block)
        fiber = Fiber.current
        after = Proc.new {|result| p [:after_inject, result]; fiber.resume(result)}
        super(obj, block, after)
        Fiber.yield 
      end
      
      # original iterator method for map support
      def inject(obj, foreach, after)
        super(obj, foreach, after)
      end

    end
  end
end
