# install tmm1's gem to make this work
require 'em-mysqlplus'

module EventMachine  
  class MySQL
    def initialize(opt = {})
      options = {
        :host        => 'localhost',
        :database    => 'test',
        :port        => 3306,
        :connections => 1, # Invalid 
        :on_error    => Proc.new {|e| p e; fail(e)},
        :logging     => false
      }.merge(opt)
      
      @mysql = EventedMysql.connect(options)
    end

    %w[select insert update raw].each do |type|
      class_eval %[
     
        def a#{type}(query)
          q  = EventMachine::DefaultDeferrable.new
          cb = Proc.new {|r| q.succeed(r) }
          eb = Proc.new {|r| q.fail(r) }
          
          @mysql.execute(query, :#{type}, cb, eb)          
          q
        end
        
        def #{type}(query)
          f = Fiber.current

          cb = Proc.new {|r| f.resume(r) }
          eb = Proc.new {|r| f.resume(r) }
          @mysql.execute(query, :#{type}, cb, eb)

          Fiber.yield
        end
      ]
    end

  end
end
