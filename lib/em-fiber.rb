$:.unshift(File.dirname(__FILE__) + '/../lib')

require "rubygems"
require "eventmachine"
require "fiber"

%w[ multi em-http ].each do |file|
  require "em-fiber/#{file}"
end
