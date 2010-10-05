require 'go'

EM.synchrony do
  c = Channel.new

  go {
    sleep(1)
    c << 'go go go sleep 1!'
  }

  puts c.pop

  EM.stop
end