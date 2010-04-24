begin
  require "em-mysqlplus"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install em-mysqlplus"
end

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
