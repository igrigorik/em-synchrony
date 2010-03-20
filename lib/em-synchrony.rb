$:.unshift(File.dirname(__FILE__) + '/../lib')

require "rubygems"
require "eventmachine"
require "fiber"

require "em-synchrony/em-multi"
require "em-synchrony/em-http"
require "em-synchrony/em-mysql"
require "em-synchrony/em-remcached"

require "em-synchrony/connection_pool"

module EventMachine

  # A convenience method for wrapping EM.run body within
  # a Ruby Fiber such that async operations can be transparently
  # paused and resumed based on IO scheduling.
  def self.synchrony(blk=nil, tail=nil, &block)
    blk ||= block
    context = Proc.new { Fiber.new { blk.call }.resume }

    self.run(context, tail)
  end

end
