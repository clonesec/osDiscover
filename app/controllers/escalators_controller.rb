class EscalatorsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  before_filter :redirect_to_root, :only => [:edit, :update]

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def index
    @escalators = Escalator.all(current_user)
  end

  def show
    @escalator = Escalator.find(params[:id], current_user)
  end

  def new
    @escalator = Escalator.new
    @escalator.persisted = false
  end

  def create
    @escalator = Escalator.new(params[:escalator])
    @escalator.persisted = false
    if @escalator.save(current_user)
      redirect_to escalators_url, :notice => "Successfully created escalator."
    else
      render :action => 'new'
    end
  end

  def edit
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def update
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def destroy
    @escalator = Escalator.find(params[:id], current_user)
    redirect_to(escalators_url, :notice => "Unable to find escalator #{params[:id]}.") and return if @escalator.blank?
    msg = @escalator.delete_record(current_user)
    if msg.blank?
      redirect_to escalators_url, :notice => "Successfully deleted escalator."
    else
      redirect_to escalators_url, :notice => msg
    end
  end

  def test_escalator
    @escalator = Escalator.find(params[:id], current_user)
    msg = @escalator.test_escalator(current_user)
    if msg.blank?
      redirect_to escalators_url, :notice => "Successfully tested escalator: #{@escalator.name}."
    else
      redirect_to escalators_url, :notice => msg
    end
  end

end