begin
  require "em-jack"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install em-jack"
end

# WANT: namespaced under EventMachine.. would be nice :-)
# NOTE: no need for "pooling" since Beanstalk supports pipelining
module EMJack
  class Connection

    alias :ause :use
    def use(tube, &blk)
      return if @used_tube == tube

      f = Fiber.current

      # WANT: per command errbacks, would be nice, instead of one global
      # errback  = Proc.new {|r| f.resume(r) }

      on_error {|r| f.resume(r)}

      @used_tube = tube
      @conn.send(:use, tube)

      # WANT: Add conditional on add_deferrable to either accept two procs, or a single block
      #       .. two procs = callback, errback
      add_deferrable { |r| f.resume(r) }

      Fiber.yield
    end

  end
end
