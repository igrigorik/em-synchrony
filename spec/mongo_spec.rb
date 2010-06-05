require "spec/helper/all"

describe EM::Mongo do

  it "should yield until connection is ready" do
    EventMachine.synchrony do
      connection = EM::Mongo::Connection.new
      connection.connected?.should be_true

      db = connection.db('db')
      db.is_a?(EventMachine::Mongo::Database).should be_true

      EventMachine.stop
    end
  end

  it "should insert a record into db" do
    EventMachine.synchrony do
      collection = EM::Mongo::Connection.new.db('db').collection('test')
      collection.remove({}) # nuke all keys in collection

      obj = collection.insert('hello' => 'world')
      obj.keys.should include '_id'

      obj = collection.find
      obj.size.should == 1
      obj.first['hello'].should == 'world'

      EventMachine.stop
    end
  end

  it "should insert a record into db" do
    EventMachine.synchrony do
      collection = EM::Mongo::Connection.new.db('db').collection('test')
      collection.remove({}) # nuke all keys in collection

      obj = collection.insert('hello' => 'world')
      obj = collection.insert('hello2' => 'world2')

      obj = collection.find({})
      obj.size.should == 2

      obj2 = collection.find({}, {:limit => 1})
      obj2.size.should == 1

      obj3 = collection.first
      obj3.is_a?(Hash).should be_true

      EventMachine.stop
    end
  end

  it "should update records in db" do
    EventMachine.synchrony do
      collection = EM::Mongo::Connection.new.db('db').collection('test')
      collection.remove({}) # nuke all keys in collection

      obj = collection.insert('hello' => 'world')
      collection.update({'hello' => 'world'}, {'hello' => 'newworld'})

      new_obj = collection.first({'_id' => obj['_id']})
      new_obj['hello'].should == 'newworld'

      EventMachine.stop
    end
  end

end
