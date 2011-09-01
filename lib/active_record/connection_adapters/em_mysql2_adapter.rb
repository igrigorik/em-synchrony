# encoding: utf-8

# AR adapter for using a fibered mysql2 connection with EM
# This adapter should be used within Thin or Unicorn with the rack-fiber_pool middleware.
# Just update your database.yml's adapter to be 'em_mysql2'

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  class Base
    def self.em_mysql2_connection(config)
      client = Mysql2::EM::Client.new(config.symbolize_keys)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::Mysql2Adapter.new(client, logger, options, config)
    end
  end
end
