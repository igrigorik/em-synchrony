module EventMachine
  module Synchrony
    class Keyboard
      attr_reader :current_fiber, :separator
      
      def gets
        @current_fiber = Fiber.current        
        EM.open_keyboard(EventMachine::Synchrony::KeyboardHandler, self)
        
        Fiber.yield
      end
    end
    
    class KeyboardHandler < EM::Connection      
      include EM::Protocols::LineText2
      
      def initialize(keyboard)
        @keyboard = keyboard
      end
          
      def receive_line(line)
        # Simulate gets by adding a trailing line feed
        @input = "#{line}#{$/}"
        
        close_connection
      end
      
      def unbind
        @keyboard.current_fiber.resume @input
      end
    end
  end
end
