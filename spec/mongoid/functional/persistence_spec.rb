require "spec/mongoid/mongoid_helper"
require 'em-synchrony/mongoid'

describe Mongoid::Persistence do

  before(:all) do
    EM.synchrony do
      Mongoid.from_hash({"host"=> "localhost", "database"=> "test", "pool_size"=>5})   
      [ Post, Link ].each(&:delete_all)
      Mongoid.persist_in_safe_mode = true
      Mongoid.parameterize_keys = false
      EventMachine.stop
    end
  end
  
  describe ".create" do
    context "when providing attributes" do
      it "saves and returns the document" do
        post = nil
        EM.synchrony do
          Mongoid.from_hash({"host"=> "localhost", "database"=> "test", "pool_size"=>5})
          post = Post.create(:title => "Sensei", :body => "Testing 1 2 3")
          EventMachine.stop
        end

        post.should be_persisted
        post.should be_a_kind_of(Post)
      end
    end
    
    it "sets attributes, persists the document" do
      post = nil
      EM.synchrony do
        Mongoid.from_hash({"host"=> "localhost", "database"=> "test", "pool_size"=>5})   
        post = Post.create do |poster|
          poster.title = "Yahooooo"
        end
        EventMachine.stop
      end        

      post.title.should eq("Yahooooo")
      post.should be_persisted
    end
    
      context "when passing in a block" do

        it "sets attributes, persists the document" do
          post = nil
          EM.synchrony do
            Mongoid.from_hash({"host"=> "localhost", "database"=> "test", "pool_size"=>5})   
            post = Post.create do |poster|
              poster.title = "Yahooooo"
            end
            EventMachine.stop
          end        

          post.title.should eq("Yahooooo")
          post.should be_persisted
        end
      end

      context "when mass assignment role is indicated" do

        context "when attributes assigned from default role" do

          it "validates the roles for mass assignment" do
            dpost = nil
            EM.synchrony do
              Mongoid.from_hash({"host"=> "localhost", "database"=> "test", "pool_size"=>5})   
              dpost = Post.create(
                :title => "Some Title",
                :body => "Some text",
                :extra_field => "something else",
                :secure_field => "secure!"
              )
              EventMachine.stop
            end          

            dpost.title.should eq("Some Title")
            dpost.extra_field.should be_nil
            dpost.secure_field.should be_nil
          end
        end
      end
    
  end
end
