begin
  require "em-http"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install em-http-request"
end

module EventMachine
  module HTTPMethods
     %w[get head post delete put].each do |type|
       class_eval %[
         alias :a#{type} :#{type}
         def #{type}(options = {}, &blk)
           f = Fiber.current

            conn = setup_request(:#{type}, options, &blk)
            conn.callback { f.resume(conn) }
            conn.errback  { f.resume(conn) }

            Fiber.yield
         end
      ]
    end
  end
end
