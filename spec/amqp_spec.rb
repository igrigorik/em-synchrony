require "spec/helper/all"

describe EM::Synchrony::AMQP do

  it "should yield until connection is ready" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      connection.connected?.should eq(true)
      EM.stop
    end
  end

  it "should yield until disconnection is complete" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      connection.disconnect
      connection.connected?.should eq(false)
      EM.stop
    end
  end

  it "should yield until the channel is created" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)
      channel.should be_kind_of(EM::Synchrony::AMQP::Channel)
      EM.stop
    end
  end

  it "should yield until the queue is created" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)
      queue = EM::Synchrony::AMQP::Queue.new(channel, "test.em-synchrony.queue1", :auto_delete => true)
      EM.stop
    end
  end

  it "should yield when a queue is created from a channel" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)
      queue = channel.queue("test.em-synchrony.queue1", :auto_delete => true)
      EM.stop
    end
  end

  it "should yield until the exchange is created" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)

      exchange = EM::Synchrony::AMQP::Exchange.new(channel, :fanout, "test.em-synchrony.exchange")
      exchange.should be_kind_of(EventMachine::Synchrony::AMQP::Exchange)

      [:direct, :fanout, :topic, :headers].each do |type|
        # Exercise cached exchange code path
        2.times.map { channel.send(type, "test.em-synchrony.#{type}") }.each do |ex|
          ex.should be_kind_of(EventMachine::Synchrony::AMQP::Exchange)
        end
      end

      EM.stop
    end
  end

  it "should publish and receive messages" do
    nb_msg = 10
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)
      ex = EM::Synchrony::AMQP::Exchange.new(channel, :fanout, "test.em-synchrony.fanout")

      q1 = channel.queue("test.em-synchrony.queues.1", :auto_delete => true)
      q2 = channel.queue("test.em-synchrony.queues.2", :auto_delete => true)

      q1.bind(ex)
      q2.bind(ex)

      nb_q1, nb_q2 = 0, 0
      stop_cb = proc { EM.stop if nb_q1 + nb_q2 == 2 * nb_msg }

      q1.subscribe(:ack => false) do |meta, msg|
        msg.should match(/^Bonjour [0-9]+/)
        nb_q1 += 1
        stop_cb.call
      end

      q2.subscribe do |meta, msg|
        msg.should match(/^Bonjour [0-9]+/)
        nb_q2 += 1
        stop_cb.call
      end

      Fiber.new do
        nb_msg.times do |n|
          ex.publish("Bonjour #{n}")
          EM::Synchrony.sleep(0.1)
        end
      end.resume
    end
  end

  it "should handle several consumers" do
    nb_msg = 10
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)
      exchange = EM::Synchrony::AMQP::Exchange.new(channel, :fanout, "test.em-synchrony.consumers.fanout")

      queue = channel.queue("test.em-synchrony.consumers.queue", :auto_delete => true)
      queue.bind(exchange)

      cons1 = EM::Synchrony::AMQP::Consumer.new(channel, queue)
      cons2 = EM::Synchrony::AMQP::Consumer.new(channel, queue)

      nb_cons1, nb_cons2 = 0, 0
      stop_cb = Proc.new do
        if nb_cons1 + nb_cons2 == nb_msg
          nb_cons1.should eq(nb_cons2)
          EM.stop
        end
      end

      cons1.on_delivery do |meta, msg|
        msg.should match(/^Bonjour [0-9]+/)
        nb_cons1 += 1
        stop_cb.call
      end.consume

      cons2.on_delivery do |meta, msg|
        msg.should match(/^Bonjour [0-9]+/)
        nb_cons2 += 1
        stop_cb.call
      end.consume

      10.times do |n|
        exchange.publish("Bonjour #{n}")
        EM::Synchrony.sleep(0.1)
      end
   end
  end
end
