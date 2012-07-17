module Mongoid
  class Cursor
    
    # em-mongo returns nil to indicate the end of the result set.
    # this makes no sense to me, but keeping em-mongo semantics the same
    # and adding a nil check here to protect downstream code used to 
    # mongo-ruby-driver semantics
    def each
      cursor.each do |document,error|
        raise OperationFailure.new(error, -1, {}) if document == :error
        yield Mongoid::Factory.from_db(klass, document) unless document.nil?
      end
    end
  end
end
