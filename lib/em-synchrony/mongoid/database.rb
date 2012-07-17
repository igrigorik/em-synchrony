# encoding: utf-8
module Mongoid #:nodoc:
  module Config #:nodoc:

    # This class handles the configuration and initialization of a mongodb
    # database using em-mongo
    class Database < Hash

      # keys to remove from self to not pass through to Mongo::Connection
      ASYNC_PRIVATE_OPTIONS = %w(uri database username password logger pool_timeout pool_size)

      # Takes the supplied options in the hash and created a URI from them to
      # pass to the Mongo connection object.
      #
      # @example Build the URI.
      #   db.build_uri
      #
      # @param [ Hash ] options The options to build with.
      #
      # @return [ String ] A mongo compliant URI string.
      #
      # @since 2.0.0.rc.1
      def build_uri(options = {})
        raise "URI not supported in async mode"
      end

      # Create the mongo master connection from either the supplied URI
      # or a generated one, while setting pool size and logging.
      #
      # @example Create the connection.
      #   db.connection
      #
      # @return [ Mongo::Connection ] The mongo connection.
      #
      # @since 2.0.0.rc.1
      def master
        EventMachine::Synchrony::ConnectionPool.new(size: (self["pool_size"] || 1) ) do
          conn = EM::Mongo::Connection.new(self["host"], (self["port"] || 27017), self["timeout"] || 1, optional)
          if authenticating?
            db = conn.db(self["database"]) 
            db.authenticate(username, password)
          end
          conn
        end
      end

      # Create the mongo slave connections from either the supplied URI
      # or a generated one, while setting pool size and logging.
      #
      # @example Create the connection.
      #   db.connection
      #
      # @return [ Array<Mongo::Connection> ] The mongo slave connections.
      #
      # @since 2.0.0.rc.1
      def slaves
        (self["slaves"] || []).map do |options|
          EventMachine::Synchrony::ConnectionPool.new(size: self["pool_size"] || 1) do
            conn = EM::Mongo::Connection.new(self["host"], (self["port"] || 27017), self["timeout"] || 0, optional(true))
            if authenticating?
              db = conn.db(self["database"]) 
              db.authenticate(username, password)
            end
            conn
          end
        end
      end

      # Get the name of the database, from either the URI supplied or the
      # database value in the options.
      #
      # @example Get the database name.
      #   db.name
      #
      # @return [ String ] The database name.
      #
      # @since 2.0.0.rc.1
      def name
        database
      end

      # Get the options used in creating the database connection.
      #
      # @example Get the options.
      #   db.options
      #
      # @param [ true, false ] slave Are the options for a slave db?
      #
      # @return [ Hash ] The hash of configuration options.
      #
      # @since 2.0.0.rc.1
      def optional(slave = false)
        ({
          # pool size is now used in the main connection setup
          # :pool_size => pool_size,
          :logger => logger? ? Mongoid::Logger.new : nil,
          :slave_ok => slave
        }).merge(self).reject { |k,v| ASYNC_PRIVATE_OPTIONS.include? k }.
          inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo} # mongo likes symbols
      end

    end
  end
end