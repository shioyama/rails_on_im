class ApplicationController < ActionController::Base
  def self.controller_path
    @controller_path ||= super.delete_prefix("my_app/application/")
  end
end
