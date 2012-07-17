module EM::Mongo
  class Database
    alias :driver_create_collection :create_collection
    def create_collection(name, options=nil)
      driver_create_collection(name)
    end
  end
  
  class Collection
    alias :driver_insert :insert
    def insert(doc_or_docs,opts=nil)
      driver_insert(doc_or_docs)
    end
      
    # Mongoid expects :_id to be "_id" (String, not a Symbol) for 
    # serialization. it looks like the mongo-ruby-driver accepts either... 
    # and it doesn't force it to be a Symbol like em-mongo does. Probably
    # should make the real em-mongo match this. Until then... flip
    # sym to string by standardizing on string...
    def sanitize_id!(doc)
      doc["_id"] = has_id?(doc) || BSON::ObjectId.new
      doc.delete(:_id)
      doc
    end
  end
end