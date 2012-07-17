require "em-mongo"
require "em-synchrony/em-mongo"
require "em-synchrony/mongoid/database"
require "em-synchrony/mongoid/cursor"
require "em-synchrony/mongoid/extras"

# disable mongoid connection initializer
if defined? Rails
  module Rails
    module Mongoid
      class Railtie < Rails::Railtie
        initializers.delete_if { |i| i.name == 'verify that mongoid is configured' }
      end
    end
  end
end
