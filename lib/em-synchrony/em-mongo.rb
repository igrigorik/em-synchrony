begin
  require "em-mongo"
rescue LoadError => error
  raise "Missing EM-Synchrony dependency: gem install em-mongo"
end

module EM
  module Mongo

    class Database
      def authenticate(username, password)
        auth_result = self.collection(SYSTEM_COMMAND_COLLECTION).first({'getnonce' => 1})

        auth                 = BSON::OrderedHash.new
        auth['authenticate'] = 1
        auth['user']         = username
        auth['nonce']        = auth_result['nonce']
        auth['key']          = EM::Mongo::Support.auth_key(username, password, auth_result['nonce'])

        auth_result2 = self.collection(SYSTEM_COMMAND_COLLECTION).first(auth)
        if EM::Mongo::Support.ok?(auth_result2)
          true
        else
          raise AuthenticationError, auth_result2["errmsg"]
        end
      end
      
      %w(collections create_collection drop_collection drop_index index_information get_last_error error? add_user).each do |name|
        class_eval <<-EOS, __FILE__, __LINE__
          alias :a#{name} :#{name}
          def #{name}(*args)
            EM::Synchrony.sync a#{name}(*args)
          end
        EOS
      end
      
      # this method is reimplemented because it requires Cursor#next_document to be async, which is no longer is.
      def command(selector, opts={})
        check_response = opts.fetch(:check_response, true)
        raise MongoArgumentError, "command must be given a selector" unless selector.is_a?(Hash) && !selector.empty?

        response = RequestResponse.new
        cmd_resp = Cursor.new(self.collection(SYSTEM_COMMAND_COLLECTION), :limit => -1, :selector => selector).anext_document

        cmd_resp.callback do |doc|
          if doc.nil?
            response.fail([OperationFailure, "Database command '#{selector.keys.first}' failed: returned null."])
          elsif (check_response && !EM::Mongo::Support.ok?(doc))
            response.fail([OperationFailure, "Database command '#{selector.keys.first}' failed: #{doc.inspect}"])
          else
            response.succeed(doc)
          end
        end

        cmd_resp.errback do |err|
          response.fail([OperationFailure, "Database command '#{selector.keys.first}' failed: #{err[1]}"])
        end

        response
      end
    end

    class Connection
      def initialize(host = DEFAULT_IP, port = DEFAULT_PORT, timeout = nil, opts = {})
        f = Fiber.current

        @em_connection = EMConnection.connect(host, port, timeout, opts)
        @db = {}
        # establish connection before returning
        @em_connection.callback { f.resume }
        @em_connection.errback { @on_close.call; f.resume }
        
        Fiber.yield
      end
      
    end

    class Collection

      # changed to make the cursor sync for versions greater than 0.3.6
      # this means find and afind are the same
      
      # afind_one is rewritten to call anext_document on the cursor returned from find
      # find_one  is sync in the original form, unchanged because cursor is changed
      # first     is sync, an alias for find_one

      alias :afind :find      
      
      # need to rewrite afind_one manually, as it calls next_document on
      # the cursor

      def afind_one(spec_or_object_id=nil, opts={})
        spec = case spec_or_object_id
               when nil
                 {}
               when BSON::ObjectId
                 {:_id => spec_or_object_id}
               when Hash
                 spec_or_object_id
               else
                 raise TypeError, "spec_or_object_id must be an instance of ObjectId or Hash, or nil"
               end
        find(spec, opts.merge(:limit => -1)).anext_document
      end
      alias :afirst :afind_one
      # alias :first :find_one

      %w(safe_insert safe_update find_and_modify map_reduce distinct group ).each do |name|
        class_eval <<-EOS, __FILE__, __LINE__
          alias :a#{name} :#{name}
          def #{name}(*args)
            EM::Synchrony.sync a#{name}(*args)
          end
        EOS
      end

      alias :mapreduce :map_reduce
      alias :amapreduce :amap_reduce

      def save(doc, opts={})
        safe_save(doc, opts.merge(:safe => false))
      end

      def update(selector, document, opts={})
        # Initial byte is 0.
        safe_update(selector, document, opts.merge(:safe => false))
      end
      
      def insert(doc_or_docs)
        safe_insert(doc_or_docs, :safe => false)
      end

    end

    class Cursor

      %w( next_document has_next? explain count ).each do |name|
        class_eval <<-EOS, __FILE__, __LINE__
          alias :a#{name} :#{name}
          def #{name}(*args)
            EM::Synchrony.sync a#{name}(*args)
          end
        EOS
      end
            
      # the following methods are hand tweaked because they are the primary interface
      # to the rest of the functionality. The key things to understand:
      #
      # - #next_document -  has an async refresh call internally (what actually runs the query for
      #     this cursor). Most users will not use this method directly, but it should work
      #     sychronously. Used internally by Cursor#explain
      # - #each - only calls next_document, and is only called by Cursor#defer_as_a internally. It is
      #     THE primary method to interact with the cursor so... MUST be sync.
      # - #defer_as_a - the fly in the ointment. It is meant to return a deferrable (hence the name). It
      #     is used by Database#collection_names and Database#index_information internally. Can be used 
      #     by developers. So LEAVE IT ASYNC. That requires an async #each impl, which makes me 
      #     itch. No better idea yet.
      # - #explain - rewriting to make it fully synchronous - just was easier for now. Mongoid does
      #     reference it as a delegated operation to the driver.
      
      # alias :anext_document :next_document
      alias :anext :anext_document
      alias :next :next_document
      
      def each(&blk)
        raise "A callback block is required for #each" unless blk
        
        # using this bizarre looping construct because next_document doesn't 
        # return nil, at least not with the current EM:Synchrony.sync impl. 
        # so, we do this. I could do a break inside, I guess, but meh. This works.
        doc = next_document
        while !doc.nil? && !(doc.kind_of?(Array) && doc.none?)
          blk.call(doc)
          doc = next_document
        end
        close
      end
      
      def aeach(&blk)
        raise "A callback block is required for #each" unless blk
        EM.next_tick do
          next_doc_resp = anext_document
          next_doc_resp.callback do |doc|
            blk.call(doc)
            doc.nil? ? close : self.aeach(&blk)
          end
          next_doc_resp.errback do |err|
            if blk.arity > 1
              blk.call(:error, err)
            else
              blk.call(:error)
            end
          end
        end
      end
      
      def to_a
        items = []
        self.each do |doc|
          if (doc != :error)
            items << doc
          end
        end
        items 
      end
      
      def defer_as_a
        response = RequestResponse.new
        items = []
        self.aeach do |doc,err|
          if doc == :error
            response.fail(err)
          elsif doc
            items << doc
          else
            response.succeed(items)
          end
        end
        response
      end
      alias :ato_a :defer_as_a
      
      def explain
        response = RequestResponse.new
        c = Cursor.new(@collection, query_options_hash.merge(:limit => -@limit.abs, :explain => true))
        explanation = c.next_document
        c.close
        explanation
      end

    end # end Cursor
    
  end
end
