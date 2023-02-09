class Tag < ApplicationRecord
  belongs_to :taggable, polymorphic: true
end
