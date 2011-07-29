class User < ActiveRecord::Base

  devise :database_authenticatable, :trackable, :timeoutable

  attr_accessible :username, :email, :password, :password_confirmation

  def openvas_connection=(conn)
    @openvas_connection ||= conn
  end

  def openvas_connection
    @openvas_connection
  end

  def openvas_admin=(admin=false)
    @openvas_admin ||= admin
  end

  def openvas_admin?
    @openvas_admin
  end

end