# encoding: utf-8

# AR adapter for using a fibered mysql2 connection with EM
# This adapter should be used within Thin or Unicorn with the rack-fiber_pool middleware.
# Just update your database.yml's adapter to be 'em_mysql2'
# to real connection pool size.

require 'em-synchrony/mysql2'
require 'em-synchrony/activerecord'
require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  class Base
    def self.em_mysql2_connection(config)
      config[:username] = 'root' if config[:username].nil?

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::EM::Client.new(config.symbolize_keys)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::EmMysql2Adapter.new(client, logger, options, config)
    end
  end

  module ConnectionAdapters
    class EmMysql2Adapter < Mysql2Adapter
      ADAPTER_NAME = 'EmMySql2'

      class Column < AbstractMysqlAdapter::Column # :nodoc:
        def adapter
          EmMysql2Adapter
        end
      end

      private

      def connect
        @connection = Mysql2::EM::Client.new(@config)
        configure_connection
      end
    end
  end
end
