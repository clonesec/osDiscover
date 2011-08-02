class PagesController < ApplicationController
  before_filter :authenticate_user!
  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter :openvas_logout
  
  def index
  end

  def help
  end

end
