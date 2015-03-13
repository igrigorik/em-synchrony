require "spec/helper/all"

describe EM::Mongo do
  it "should yield until connection is ready" do
    EventMachine.synchrony do
      connection = EM::Mongo::Connection.new
      connection.connected?.should eq(true)

      db = connection.db('db')
      db.is_a?(EventMachine::Mongo::Database).should eq(true)

      EventMachine.stop
    end
  end

  describe 'Synchronously (find & first)' do
    it "should insert a record into db" do
      EventMachine.synchrony do
        collection = EM::Mongo::Connection.new.db('db').collection('test')
        collection.remove({}) # nuke all keys in collection

        obj = collection.insert('hello' => 'world')
        obj.should be_a(BSON::ObjectId)

        obj = collection.find
        obj.size.should == 1
        obj.first['hello'].should == 'world'

        EventMachine.stop
      end
    end

    it "should insert a record into db and be able to find it" do
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
        obj3.is_a?(Hash).should eq(true)

        EventMachine.stop
      end
    end

    it "should be able to order results" do
      EventMachine.synchrony do
        collection = EM::Mongo::Connection.new.db('db').collection('test')
        collection.remove({}) # nuke all keys in collection

        collection.insert(:name => 'one', :position => 0)
        collection.insert(:name => 'three', :position => 2)
        collection.insert(:name => 'two', :position => 1)

        res = collection.find({}, {:order => 'position'})
        res[0]["name"].should == 'one'
        res[1]["name"].should == 'two'
        res[2]["name"].should == 'three'

        res1 = collection.find({}, {:order => [:position, :desc]})
        res1[0]["name"].should == 'three'
        res1[1]["name"].should == 'two'
        res1[2]["name"].should == 'one'

        EventMachine.stop
      end
    end
  end


  #
  # em-mongo version > 0.3.6
  #
  if defined?(EM::Mongo::Cursor)
    describe '*A*synchronously (afind & afirst) [Mongo > 0.3.6, using cursor]' do
      it "should insert a record into db" do
        EventMachine.synchrony do
          collection = EM::Mongo::Connection.new.db('db').collection('test')
          collection.remove({}) # nuke all keys in collection

          obj = collection.insert('hello' => 'world')
          obj.should be_a(BSON::ObjectId)

          cursor = collection.afind
          cursor.should be_a(EM::Mongo::Cursor)
          cursor.to_a.callback do |obj|
            obj.size.should == 1
            obj.first['hello'].should == 'world'
            EM.next_tick{ EventMachine.stop }
          end
        end
      end

      it "should insert a record into db and be able to find it" do
        EventMachine.synchrony do
          collection = EM::Mongo::Connection.new.db('db').collection('test')
          collection.remove({}) # nuke all keys in collection

          obj = collection.insert('hello' => 'world')
          obj = collection.insert('hello2' => 'world2')

          collection.afind({}).to_a.callback do |obj|
            obj.size.should == 2
          end
          collection.afind({}, {:limit => 1}).to_a.callback do |obj2|
            obj2.size.should == 1
          end
          collection.afirst.callback do |obj3|
            obj3.is_a?(Hash).should eq(true)
            obj3['hello'].should == 'world'
            EM.next_tick{ EventMachine.stop }
          end
        end
      end

      it "should be able to order results" do
        EventMachine.synchrony do
          collection = EM::Mongo::Connection.new.db('db').collection('test')
          collection.remove({}) # nuke all keys in collection

          collection.insert(:name => 'one', :position => 0)
          collection.insert(:name => 'three', :position => 2)
          collection.insert(:name => 'two', :position => 1)

          collection.afind({}, {:order => 'position'}).to_a.callback do |res|
            res[0]["name"].should == 'one'
            res[1]["name"].should == 'two'
            res[2]["name"].should == 'three'
          end

          collection.afind({}, {:order => [:position, :desc]}).to_a.callback do |res1|
            res1[0]["name"].should == 'three'
            res1[1]["name"].should == 'two'
            res1[2]["name"].should == 'one'
            EM.next_tick{ EventMachine.stop }
          end

        end
      end
    end

  else
    describe '*A*synchronously (afind & afirst) [Mongo <= 0.3.6, using blocks]' do
      it "should insert a record into db" do
        EventMachine.synchrony do
          collection = EM::Mongo::Connection.new.db('db').collection('test')
          collection.remove({}) # nuke all keys in collection

          obj = collection.insert('hello' => 'world')
          obj.should be_a(BSON::ObjectId)

          ret_val = collection.afind do |obj|
            obj.size.should == 1
            obj.first['hello'].should == 'world'
            EM.next_tick{ EventMachine.stop }
          end
          ret_val.should be_a(Integer)
        end
      end

      it "should insert a record into db and be able to find it" do
        EventMachine.synchrony do
          collection = EM::Mongo::Connection.new.db('db').collection('test')
          collection.remove({}) # nuke all keys in collection

          obj = collection.insert('hello' => 'world')
          obj = collection.insert('hello2' => 'world2')

          collection.afind({}) do |obj|
            obj.size.should == 2
          end
          collection.afind({}, {:limit => 1}) do |obj2|
            obj2.size.should == 1
          end
          collection.afirst do |obj3|
            obj3.is_a?(Hash).should eq(true)
            obj3['hello'].should == 'world'
            EM.next_tick{ EventMachine.stop }
          end
        end
      end

      it "should be able to order results" do
        EventMachine.synchrony do
          collection = EM::Mongo::Connection.new.db('db').collection('test')
          collection.remove({}) # nuke all keys in collection

          collection.insert(:name => 'one', :position => 0)
          collection.insert(:name => 'three', :position => 2)
          collection.insert(:name => 'two', :position => 1)

          collection.afind({}, {:order => 'position'}) do |res|
            res[0]["name"].should == 'one'
            res[1]["name"].should == 'two'
            res[2]["name"].should == 'three'
          end

          collection.afind({}, {:order => [:position, :desc]}) do |res1|
            res1[0]["name"].should == 'three'
            res1[1]["name"].should == 'two'
            res1[2]["name"].should == 'one'
            EM.next_tick{ EventMachine.stop }
          end

        end
      end
    end

  end

  it "should update records in db" do
    EventMachine.synchrony do
      collection = EM::Mongo::Connection.new.db('db').collection('test')
      collection.remove({}) # nuke all keys in collection

      obj_id = collection.insert('hello' => 'world')
      collection.update({'hello' => 'world'}, {'hello' => 'newworld'})

      new_obj = collection.first({'_id' => obj_id})
      new_obj['hello'].should == 'newworld'

      EventMachine.stop
    end
  end

  context "authentication" do
    # these specs only get asserted if you run mongod with the --auth flag
    it "successfully authenticates", ci_skip: true do
      # For this spec you will need to add this user to the database
      #
      # From the Mongo shell:
      # > use db
      # > db.addUser('test', 'test')
      EventMachine.synchrony do
        database = EM::Mongo::Connection.new.db('db')
        database.authenticate('test', 'test').should == true
        EventMachine.stop
      end
    end

    it "raises an AuthenticationError if it cannot authenticate" do
      EventMachine.synchrony do
        database = EM::Mongo::Connection.new.db('db')
        proc {
          database.authenticate('test', 'wrong_password')
        }.should raise_error(EventMachine::Mongo::AuthenticationError, "auth fails")
        EventMachine.stop
      end
    end
  end
end
