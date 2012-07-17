class Comment
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :title
  field :body
  field :author_name
  
  embedded_in :posts
  
  validates_presence_of :title
  
end
