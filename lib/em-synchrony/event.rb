module EM::Synchrony
  class Event
    attr_reader :waiters
    def initialize
      @waiters = []
      @setted = false
    end

    def set(result = nil)
      @setted = true
      @result = result
      waiters.each { |v| v.resume result }
    end

    def wait
      if @setted
        @result
      else
        waiters << Fiber.current
        Fiber.yield
      end
    end
  end
end