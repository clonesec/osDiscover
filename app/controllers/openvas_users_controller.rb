class OpenvasUsersController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_oap_connect_and_login
  after_filter :openvas_logout

  def index
    @openvas_users = OpenvasUser.all(current_user)
  end

  def show
    @openvas_user = OpenvasUser.find(params[:name], current_user)
  end

  def new
    @openvas_user = OpenvasUser.new
    @openvas_user.persisted = false
  end

  def create
    @openvas_user = OpenvasUser.new(params[:openvas_user])
    @openvas_user.persisted = false
    if @openvas_user.save(current_user)
      redirect_to openvas_users_url, notice: "Successfully created user."
    else
      render action: 'new'
    end
  end

  def edit
    @openvas_user = OpenvasUser.find(params[:id], current_user)
    @openvas_user.password = ''
    @openvas_user.persisted = true
  end

  def update
    @openvas_user = OpenvasUser.find(params[:id], current_user)
    @openvas_user.persisted = true
    if @openvas_user.update_attributes(current_user, params[:openvas_user])
      redirect_to openvas_users_url, notice:  "Successfully updated user."
    else
      render action: 'edit'
    end
  end

  def destroy
    @openvas_user = OpenvasUser.find(params[:id], current_user)
    redirect_to(openvas_users_url, notice: "Unable to find user #{params[:id]}.") and return if @openvas_user.blank?
    redirect_to(openvas_users_url, alert: "You can't delete yourself.") and return if current_user.username.downcase == @openvas_user.name.downcase
    msg = @openvas_user.delete_record(current_user)
    if msg.blank?
      redirect_to openvas_users_url, notice: "Successfully deleted user."
    else
      redirect_to openvas_users_url, notice: msg
    end
  end

end