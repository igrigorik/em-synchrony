require "lib/em-synchrony"

EM.synchrony do

  # open 4 concurrent MySQL connections
  db = EventMachine::Synchrony::ConnectionPool.new(size: 4) do
    EventMachine::MySQL.new(host: "localhost")
  end

  # perform 4 http requests in parallel, and collect responses
  multi = EventMachine::Synchrony::Multi.new
  multi.add :page1, EventMachine::HttpRequest.new("http://service.com/page1").aget
  multi.add :page2, EventMachine::HttpRequest.new("http://service.com/page2").aget
  multi.add :page3, EventMachine::HttpRequest.new("http://service.com/page3").aget
  multi.add :page4, EventMachine::HttpRequest.new("http://service.com/page4").aget
  data = multi.perform.responses[:callback].values

  # insert fetched HTTP data into a mysql database, using at most 2 connections at a time
  # - note that we're writing async code within the callback!
  EM::Synchrony::Iterator.new(data, 2).each do |page, iter|
    db.aquery("INSERT INTO table (data) VALUES(#{page});")
    db.callback { iter.return(http) }
  end

  puts "All done! Stopping event loop."
  EventMachine.stop
end