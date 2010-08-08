require 'go'

EM.synchrony do
  def producer(c, n, s)
    n.times do |i|
      puts "producer: #{i}"
      c << i
    end

    s << "producer finished"
  end

  consumer = ->(c, n, s) do
    n.times do |i|
      puts "consumer 1 got: #{c.pop}"
    end

    s << "consumer finished"
  end

  c = Channel.new(size: 2)
  s = Channel.new
  n = 10

  # mix the syntax, just for fun...
  go c,n,s, &method(:producer)
  go c,n-1,s, &consumer

  go c,s do |c, s|
    puts "consumer 2 got: #{c.pop}"
    s << "consumer 2 finished"
  end

  3.times { puts s.pop }

  EM.stop
end

# (M=6c0863) igrigorik /git/em-synchrony/examples/go> ruby consumer-publisher.rb
# producer: 0
# producer: 1
# consumer 1 got: [0]
# producer: 2
# consumer 2 got: [1]
# producer: 3
# consumer 1 got: [2]
# producer: 4
# consumer 2 finished
# consumer 1 got: [3]
# producer: 5
# consumer 1 got: [4]
# producer: 6
# consumer 1 got: [5]
# producer: 7
# consumer 1 got: [6]
# producer: 8
# consumer 1 got: [7]
# producer: 9
# consumer 1 got: [8]
# consumer 1 got: [9]
# producer finished
# consumer finished
