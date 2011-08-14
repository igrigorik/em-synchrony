module EventMachine
  module Synchrony

    class FiberIterator < EM::Synchrony::Iterator

      # execute each iterator block within its own fiber
      # and auto-advance the iterator after each call
      def each(foreach=nil, after=nil, &blk)
        fe = Proc.new do |obj, iter|
          Fiber.new { (foreach || blk).call(obj); iter.next }.resume
        end

        super(fe, after)
      end

    end
  end
end
