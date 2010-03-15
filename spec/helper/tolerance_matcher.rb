#
# courtesy of sander 6
# - http://github.com/sander6/custom_matchers/blob/master/lib/matchers/tolerance_matchers.rb
#
module Sander6
  module CustomMatchers
    
    class ToleranceMatcher
      def initialize(tolerance)
        @tolerance = tolerance
        @target = 0
      end

      def of(target)
        @target = target
        self
      end

      def matches?(value)
        @value = value
        ((@target - @tolerance)..(@target + @tolerance)).include?(@value)
      end

      def failure_message
        "Expected #{@value.inspect} to be within #{@tolerance.inspect} of #{@target.inspect}, but it wasn't.\n" +
          "Difference: #{@value - @target}"
          end

      def negative_failure_message
        "Expected #{@value.inspect} not to be within #{@tolerance.inspect} of #{@target.inspect}, but it was.\n" +
          "Difference: #{@value - @target}"
          end
    end

    def be_within(value)
      Sander6::CustomMatchers::ToleranceMatcher.new(value)
    end

  end
end
