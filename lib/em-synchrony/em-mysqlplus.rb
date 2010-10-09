begin
  require "mysqlplus"
  require "em-mysqlplus"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install mysqlplus, gem install em-mysqlplus"
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

      result = Fiber.yield
      raise result if Mysql::Error == result.class
      result
    end

  end
end
