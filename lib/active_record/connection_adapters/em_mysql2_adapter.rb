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
      client = EM::Synchrony::ActiveRecord::ConnectionPool.new(size: config[:pool]) do
        conn = ActiveRecord::ConnectionAdapters::EMMysql2Adapter::Client.new(config.symbolize_keys)
        # From Mysql2Adapter#configure_connection
        conn.query_options.merge!(:as => :array)

        # By default, MySQL 'where id is null' selects the last inserted id.
        # Turn this off. http://dev.rubyonrails.org/ticket/6778
        variable_assignments = ['SQL_AUTO_IS_NULL=0']
        encoding = config[:encoding]
        variable_assignments << "NAMES '#{encoding}'" if encoding

        wait_timeout = config[:wait_timeout]
        wait_timeout = 2592000 unless wait_timeout.is_a?(Fixnum)
        variable_assignments << "@@wait_timeout = #{wait_timeout}"

        conn.query("SET #{variable_assignments.join(', ')}")
        conn
      end 
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ActiveRecord::ConnectionAdapters::EMMysql2Adapter.new(client, logger, options, config)
    end
  end

  module ConnectionAdapters
    class EMMysql2Adapter < ::ActiveRecord::ConnectionAdapters::Mysql2Adapter
      class Client < Mysql2::EM::Client
        include EM::Synchrony::ActiveRecord::Client
      end

      if Gem::Version.new(::ActiveRecord::VERSION::STRING) >= Gem::Version.new('4.2')
        require 'em-synchrony/activerecord_4_2'
        include EM::Synchrony::ActiveRecord::Adapter_4_2
      else
        include EM::Synchrony::ActiveRecord::Adapter
      end
    end
  end
end
