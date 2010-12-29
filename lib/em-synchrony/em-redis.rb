begin
  require 'em-redis'
rescue LoadError => error
  raise 'Missing EM-Synchrony dependency: gem install em-redis'
end

module EventMachine
  module Protocols
    module Redis
      attr_reader :connected

      class << self
        alias :aconnect :connect
      end

      def self.connect(*args)
        f = Fiber.current

        conn = self.aconnect(*args)
        conn.callback { f.resume(conn) }

        Fiber.yield
      end
      
      alias :old_call_command :call_command
      
      def call_command(argv, &blk)
        # async commands are 'a' prefixed, but do check
        # for the 'add' command corner case (ugh)
        if argv.first.size > 3 && argv.first[0] == 'a'
          argv[0] = argv[0].to_s.slice(1,argv[0].size)
          old_call_command(argv, &blk)

        else
          # wrap response blocks into fiber callbacks
          # to emulate the sync api
          f = Fiber.current
          blk = proc { |v| v } if !block_given?
          clb = proc { |v| f.resume(blk.call(v)) }

          old_call_command(argv, &clb)
          Fiber.yield
        end
      end
    end
  end
end