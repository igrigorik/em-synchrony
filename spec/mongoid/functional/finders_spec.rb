require "spec/mongoid/mongoid_helper"

describe "Mongoid Finders" do

  it "should find one" do
    
    post = nil

    EM.synchrony do
      begin
        Mongoid.from_hash({"host"=> "localhost", "port"=>27017, "database"=> "test", "pool_size"=>10})
        Post.create(title: "Sample Post Alpha!", body: "rocking the rocker rocket. (yes, I'm tired...)")
        Post.create(title: "Sample Post Beta!", body: "rocking the rocker rocket. (yes, I'm tired...)")
        Post.create(title: "Sample Post Gamma!", body: "rocking the rocker rocket. (yes, I'm tired...)")
        post = Post.first
      rescue Exception,Error
        puts $!
      end
      EM.stop
    end
    
    post.should_not be_nil
    post.title.should eq("Sample Post Alpha!")
    
  end

  it "should find a simple document" do
    
    doc = nil

    EM.synchrony do
      begin
        Mongoid.from_hash({"host"=> "localhost", "port"=>27017, "database"=> "test", "pool_size"=>10})
        SimpleDocument.delete_all
        SimpleDocument.create(name: "Simple Doc Alpha!")
        doc = SimpleDocument.first
      rescue Exception,Error
        puts $!
      end
      EM.stop
    end
    
    doc.should_not be_nil
    doc.name.should eq("Simple Doc Alpha!")
    
  end
  
  it "should traverse a relation" do
    link = nil
    
    puts "traverse"
    
    EM.synchrony do
      begin
        Mongoid.from_hash({"host"=> "localhost", "port"=>27017, "database"=> "test", "pool_size"=>10})
        puts "creating post"
        p = Post.create(title: "Link Testing Post")
        puts "got p - #{p.new_record?}"
        puts "creating link 1"
        l1 = Link.new(url: "http://apple.com", score: 10)
        l1.post = p
        puts "saving #{l1.save}"
        l1.reload
        puts "creating link 2"
        l2 = Link.new(url: "http://windowsphone.com", score: 9)
        l2.post = p
        puts "saving #{l2.save}"
        puts "creating link 3"
        l3 = Link.new(url: "http://android.com", score: 8)
        l3.post = p
        puts "saving #{l3.save}"

        link = p.links.order_by([:score, :desc]).first
      rescue Exception,Error
        puts $!        
      end
      EM.stop
    end
    
    link.should_not be_nil
    link.url.should eq("http://apple.com")
    link.score.should eq(10)

  end


  it "should find a Link" do

    puts "fourth test - should find a link"
    
    link = nil

    EM.synchrony do
      puts "synchro started"
      begin
        Mongoid.from_hash({"host"=> "localhost", "port"=>27017, "database"=> "test", "pool_size"=>10})
        puts "connected!"
        Link.delete_all
        puts "boom"
        Link.create(url: "http://fatmixx.com")
        link = Link.first
      rescue Exception,Error
        puts $!
      end
      EM.stop
    end
    
    link.should_not be_nil
    link.url.should eq("http://fatmixx.com")
    
  end

  
end
