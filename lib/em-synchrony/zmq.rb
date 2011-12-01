require 'em-synchrony'
require 'rehub/em-synchrony'
require 'ffi-rzmq'
module ZMQ
  class Socket
    alias :bsend :send
    def send(message, flags = 0)
      flags |= ZMQ::Util.nonblocking_flag
      while EM.reactor_running? do
        sock_wait false, true
        rc = bsend message, flags
        unless rc == -1 && ZMQ::Util.errno == EAGAIN
          return rc
        end
      end
    end

    alias :brecv :recv
    def recv(message, flags = 0)
      flags |= ZMQ::Util.nonblocking_flag
      while EM.reactor_running? do
        sock_wait true, false
        rc = brecv message, flags
        unless rc == -1 && ZMQ::Util.errno == EAGAIN
          return rc
        end
      end
    end

    protected

    def sock_wait(read = false, write = false)
      events = getsockopt_or_false(ZMQ::EVENTS)
      if read && (events & ZMQ::POLLIN) == ZMQ::POLLIN
        return
      elsif write && (events & ZMQ::POLLOUT) == ZMQ::POLLOUT
        return
      else
        EM::Synchrony.trampoline(getsockopt_or_false(ZMQ::FD), read: read, write: write)
      end
    end

    def getsockopt_or_false(option)
      array = []
      rc = getsockopt(option, array)
      ZMQ::Util.resultcode_ok?(rc) ? array.at(0) : false
    end
  end
end