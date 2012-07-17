class SimpleDocument
  include Mongoid::Document
  
  field :name
  field :counter, :type=>Integer

end