# encoding: utf-8

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  class Base
    def self.fibered_mysql2_connection(config)
      client = EM::Synchrony::ConnectionPool.new(size: config[:real_pool]) do
        conn = Mysql2::EM::Client.new(config.symbolize_keys)

        # From Mysql2Adapter#configure_connection
        conn.query_options.merge!(:as => :array)

        # By default, MySQL 'where id is null' selects the last inserted id.
        # Turn this off. http://dev.rubyonrails.org/ticket/6778
        variable_assignments = ['SQL_AUTO_IS_NULL=0']
        encoding = config[:encoding]

        # make sure we set the encoding
        variable_assignments << "NAMES '#{encoding}'" if encoding

        # increase timeout so mysql server doesn't disconnect us
        wait_timeout = config[:wait_timeout]
        wait_timeout = 2592000 unless wait_timeout.is_a?(Fixnum)
        variable_assignments << "@@wait_timeout = #{wait_timeout}"

        conn.query("SET #{variable_assignments.join(', ')}")
        conn
      end
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::Mysql2Adapter.new(client, logger, options, config)
    end
  end

  module ConnectionAdapters
    class FiberedMysql2Adapter < Mysql2Adapter
      def configure_connection
        nil
      end
    end
  end
end
