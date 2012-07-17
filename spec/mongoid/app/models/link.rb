class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :url
  field :score, type: Integer, default: 0
  
  belongs_to :post
  
end