require 'em/mysql'

module EventMachine
  class Query
    include EventMachine::Deferrable
  end
  
  class MySQL
    def initialize(opt = {})
      options = {
        :host        => 'localhost',
        :database    => 'test',
        :port        => 3306,
        :connections => 1,
        :on_error    => Proc.new {|e| p e; fail(e)},
        :logging     => false
      }.merge(opt)
      
      EventedMysql.settings.update options
    end

    %w[select insert update raw].each do |type|
      class_eval %[
     
        def a#{type}(query)
          q  = EventMachine::Query.new
          cb = Proc.new {|r| q.succeed(r) }
          eb = Proc.new {|r| q.fail(r) }
          
          EventedMysql.execute(query, :#{type}, cb, eb)          
          q
        end
        
        def #{type}(query)
          f = Fiber.current

          callback = Proc.new {|r| f.resume(r) }
          errback  = Proc.new {|r| f.resume(r) }
          EventedMysql.execute(query, :#{type}, callback, errback)

          Fiber.yield
        end
      ]
    end

  end
end
