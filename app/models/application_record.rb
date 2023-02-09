class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def to_partial_path
    @_to_partial_path ||= super.delete_prefix("my_app/application/")
  end
end
