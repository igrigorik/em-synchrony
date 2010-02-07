$:.unshift(File.dirname(__FILE__) + '/../lib')

require "rubygems"
require "eventmachine"
require "fiber"

%w[ em-multi em-http em-mysql ].each do |file|
  require "em-fiber/#{file}"
end
