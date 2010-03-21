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
        result = nil

        after = Proc.new {|res| result = res; fiber.resume }
        super(block, after)

        Fiber.yield
        result
      end

      def inject(obj, foreach = nil, after = nil, &block)
        if foreach and after
          super(obj, foreach, after)
        else
          fiber = Fiber.current
          result = nil

          after = Proc.new {|res| result = res; fiber.resume}
          super(obj, block, after)

          Fiber.yield
          result
        end
      end

    end
  end
end
