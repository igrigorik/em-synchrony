require "spec/helper/all"

DELAY = 0.25
QUERY = "select sleep(#{DELAY})"

describe EventMachine::Synchrony::ConnectionPool do

  it "should queue requests if pool size is exceeded" do
    EventMachine.run do

      db = EventMachine::Synchrony::ConnectionPool.new(size: 1) do
        Mysql2::EM::Client.new
      end

      Fiber.new {
        start = now

        multi = EventMachine::Synchrony::Multi.new
        multi.add :a, db.aquery(QUERY)
        multi.add :b, db.aquery(QUERY)
        res = multi.perform

        (now - start.to_f).should be_within(DELAY * 2 * 0.15).of(DELAY * 2)
        res.responses[:callback].size.should == 2
        res.responses[:errback].size.should == 0

        EventMachine.stop
      }.resume
    end
  end

  it "should execute multiple async pool requests within same fiber" do
    EventMachine.run do

      db = EventMachine::Synchrony::ConnectionPool.new(size: 2) do
        Mysql2::EM::Client.new
      end

      Fiber.new {
        start = now

        multi = EventMachine::Synchrony::Multi.new
        multi.add :a, db.aquery(QUERY)
        multi.add :b, db.aquery(QUERY)
        res = multi.perform

        (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
        res.responses[:callback].size.should == 2
        res.responses[:errback].size.should == 0

        EventMachine.stop
      }.resume
    end
  end

  it "should share connection pool between different fibers" do
    EventMachine.run do

      db = EventMachine::Synchrony::ConnectionPool.new(size: 2) do
        Mysql2::EM::Client.new
      end

      Fiber.new {
        start = now
        results = []

        fiber = Fiber.current
        2.times do |n|
          Fiber.new {
            results.push db.query(QUERY)
            fiber.transfer if results.size == 2
          }.resume
        end

        # wait for workers
        Fiber.yield

        (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
        results.size.should == 2

        EventMachine.stop
      }.resume

    end
  end

  it "should share connection pool between different fibers & async requests" do
    EventMachine.run do

      db = EventMachine::Synchrony::ConnectionPool.new(size: 5) do
        Mysql2::EM::Client.new
      end

      Fiber.new {
        start = now
        results = []

        fiber = Fiber.current
        2.times do |n|
          Fiber.new {

            multi = EventMachine::Synchrony::Multi.new
            multi.add :a, db.aquery(QUERY)
            multi.add :b, db.aquery(QUERY)
            results.push multi.perform

            fiber.transfer if results.size == 3
          }.resume
        end

        Fiber.new {
          # execute a synchronous requests
          results.push db.query(QUERY)
          fiber.transfer if results.size == 3
        }.resume

        # wait for workers
        Fiber.yield

        (now - start.to_f).should be_within(DELAY * 0.15).of(DELAY)
        results.size.should == 3

        EventMachine.stop
      }.resume

    end
  end

  describe '#pool_status' do
    it 'should return right initial size' do
      (1..10).each do |count|
        pool = EventMachine::Synchrony::ConnectionPool.new(size: count) { }
        status = pool.pool_status
        expect(status).to include available: count
        expect(status).to include reserved: 0
        expect(status).to include pending: 0
      end
    end
    it 'should return up-to-date statusrmation' do
      sleep = 0.5
      count = 5
      EM.run do
        pool = EM::Synchrony::ConnectionPool.new(size: count) do
          -> { EM::Synchrony.sleep(sleep) }
        end
        (1..count).each do |used|
          Fiber.new { pool.call }.resume
          status = pool.pool_status
          expect(status).to include available: count - used
          expect(status).to include reserved: used
          expect(status).to include pending: 0
        end
        (1..count).each do |used|
          Fiber.new { pool.call }.resume
          status = pool.pool_status
          expect(status).to include available: 0
          expect(status).to include reserved: count
          expect(status).to include pending: used
        end
        Fiber.new {
          EM::Synchrony.sleep(sleep + 0.1)
          expect(pool.pool_status).to include pending: 0

          EM::Synchrony.sleep(sleep + 0.1)
          status = pool.pool_status
          expect(status).to include available: count
          expect(status).to include reserved: 0
          expect(status).to include pending: 0
          EM.stop
        }.resume
      end
    end
  end
end
