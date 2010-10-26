require 'spec/helper/all'
require 'lib/em-synchrony/mongo'
require 'mongo'

describe Mongo::Connection do
  it 'connects to DB' do
    EventMachine.synchrony do
      conn = Mongo::Connection.new 'localhost', 27017, :connect => true
      EM.stop
    end
  end
end
