require "lib/em-synchrony"
require "net/http"

$VERBOSE = nil

EM.synchrony do
  # monkey patch default Socket code to use EventMachine Sockets instead
  TCPSocket = EventMachine::Synchrony::TCPSocket

  Net::HTTP.get_print 'www.google.com', '/index.html'

  EM.stop
end
