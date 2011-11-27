require "spec/helper/all"
require 'pp'
require 'ruby-debug'

describe EM::Synchrony::AMQP do

  it "should yield until connection is ready" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      connection.connected?.should be_true
      EM.stop
    end
  end

  it "should yield until disconnection is complete" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      connection.disconnect
      connection.connected?.should be_false
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

  it "should yield until the exchange is created" do
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)

      exchange = EM::Synchrony::AMQP::Exchange.new(channel, :fanout, "test.em-synchrony.exchange")
      exchange.should be_kind_of(EventMachine::Synchrony::AMQP::Exchange)

      direct = channel.fanout("test.em-synchrony.direct")
      fanout = channel.fanout("test.em-synchrony.fanout")
      topic = channel.fanout("test.em-synchrony.topic")
      headers = channel.fanout("test.em-synchrony.headers")

      direct.should be_kind_of(EventMachine::Synchrony::AMQP::Exchange)
      fanout.should be_kind_of(EventMachine::Synchrony::AMQP::Exchange)
      topic.should be_kind_of(EventMachine::Synchrony::AMQP::Exchange)
      headers.should be_kind_of(EventMachine::Synchrony::AMQP::Exchange)
      EM.stop
    end
  end

  it "should publish and receive messages" do
    publish_number = 10
    EM.synchrony do
      connection = EM::Synchrony::AMQP.connect
      channel = EM::Synchrony::AMQP::Channel.new(connection)
      ex = EM::Synchrony::AMQP::Exchange.new(channel, :fanout, "test.em-synchrony.fanout")

      q1 = EM::Synchrony::AMQP::Queue.new(channel, "test.em-synchrony.queues.1", :auto_delete => true)
      q2 = EM::Synchrony::AMQP::Queue.new(channel, "test.em-synchrony.queues.2", :auto_delete => true)

      q1.bind(ex)
      q2.bind(ex)

      q1_nb, q2_nb = 0, 0
      stop_cb = proc { EM.stop if q1_nb + q2_nb == 2 * publish_number }

      q1.subscribe do |meta, msg|
        msg.should match(/^Bonjour [0-9]+/)
        q1_nb += 1
        stop_cb.call
      end

      q2.subscribe do |meta, msg|
        msg.should match(/^Bonjour [0-9]+/)
        q2_nb += 1
        stop_cb.call
      end

      Fiber.new do
        publish_number.times do |n|
          ex.publish("Bonjour #{n}")
          EM::Synchrony.sleep(0.1)
        end
      end.resume
    end
  end

end
