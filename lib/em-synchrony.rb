$:.unshift(File.dirname(__FILE__) + '/../lib')

require "rubygems"
require "eventmachine"
require "fiber"

require "em-synchrony/em-multi"
require "em-synchrony/em-http"
require "em-synchrony/em-mysql"
# require "em-synchrony/em-jack"
require "em-synchrony/em-remcached"

require "em-synchrony/connection_pool"