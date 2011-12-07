# encoding: utf-8

# AR adapter for using a fibered mysql2 connection with EM
# This adapter should be used within Thin or Unicorn with the rack-fiber_pool middleware.
# Just update your database.yml's adapter to be 'em_mysql2', set :pool to 1 and :real_pool
# to real connection pool size.

module ActiveRecord
  class Base
    def self.em_mysql2_connection(config)
      client = EM::Synchrony::ActiveRecord::ConnectionPool.new(size: config[:real_pool]) do
        conn = EM::Synchrony::ActiveRecord::Mysql2Client.new(config.symbolize_keys)
        conn.open_transactions = 0
        conn.acquired = 0
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
      EM::Synchrony::ActiveRecord::Adapter.new(client, logger, options, config)
    end
  end
end
