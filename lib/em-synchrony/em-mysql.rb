require "em-mysqlplus"

module EventMachine
  class MySQL

    alias :aquery :query
    def query(sql, &blk)
      f = Fiber.current

      # TODO: blk case does not work. Hmm?
      cb = Proc.new { |r| f.resume(r) }
      eb = Proc.new { |r| f.resume(r) }

      @connection.execute(sql, cb, eb)

      Fiber.yield
    end

  end
end
