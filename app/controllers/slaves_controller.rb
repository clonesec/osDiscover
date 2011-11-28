class SlavesController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  before_filter :redirect_to_root, only: [:edit, :update]

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def index
    @slaves = Slave.all(current_user)
  end

  def show
    @slave = Slave.find(params[:id], current_user)
  end

  def new
    @slave = Slave.new
    @slave.persisted = false
  end

  def create
    @slave = Slave.new(params[:slave])
    @slave.persisted = false
    if @slave.save(current_user)
      redirect_to slaves_url, notice: "Successfully created slave."
    else
      render action: 'new'
    end
  end

  def edit
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def update
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def destroy
    @slave = Slave.find(params[:id], current_user)
    redirect_to(slaves_url, notice: "Unable to find slave #{params[:id]}.") and return if @slave.blank?
    msg = @slave.delete_record(current_user)
    if msg.blank?
      redirect_to slaves_url, notice: "Successfully deleted slave."
    else
      redirect_to slaves_url, notice: msg
    end
  end

end