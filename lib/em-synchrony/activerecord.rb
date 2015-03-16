require 'em-synchrony'

ActiveSupport.on_load(:active_record) do
  class ActiveRecord::ConnectionAdapters::ConnectionPool
    include EventMachine::Synchrony::MonitorMixin

    def current_connection_id #:nodoc:
      ActiveRecord::Base.connection_id ||= Fiber.current.object_id
    end

    def clear_stale_cached_connections!
      []
    end
  end

  class ActiveRecord::ConnectionAdapters::AbstractAdapter
    include EventMachine::Synchrony::MonitorMixin
  end
end
