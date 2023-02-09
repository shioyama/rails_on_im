class Comment < ApplicationRecord
  belongs_to :post
  has_many :tags, as: :taggable
end
