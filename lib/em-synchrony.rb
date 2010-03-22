$:.unshift(File.dirname(__FILE__) + '/../lib')

require "rubygems"
require "eventmachine"
require "fiber" unless defined? Fiber

require "em-synchrony/em-multi"
# require "em-synchrony/iterator" # iterators are not release in EM yet
require "em-synchrony/connection_pool"

require "em-synchrony/em-http"
require "em-synchrony/em-mysql"
require "em-synchrony/em-remcached"

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
