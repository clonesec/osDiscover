class ScanTargetsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  before_filter :redirect_to_root, :only => [:edit, :update]

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def index
    @scan_targets = ScanTarget.all(current_user)
  end

  def show
    @scan_target = ScanTarget.find(params[:id], current_user)
  end

  def new
    @scan_target = ScanTarget.new
  end

  def create
    @scan_target = ScanTarget.new(params[:scan_target])
    @scan_target.persisted = false
    if @scan_target.save(current_user)
      # redirect_to(@scan_target, :notice => 'Scan Target was successfully created.')
      redirect_to(scan_targets_url, :notice => 'Scan Target was successfully created.')
    else
      render :action => "new"
    end
  end

  def edit
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def update
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def destroy
    @scan_target = ScanTarget.find(params[:id], current_user)
    redirect_to(scan_targets_url, :notice => "Unable to find scan target #{params[:id]}.") and return if @scan_target.blank?
    msg = @scan_target.delete_record(current_user)
    if msg.blank?
      redirect_to scan_targets_url, :notice => "Successfully deleted scan target."
    else
      redirect_to scan_targets_url, :notice => msg
    end
  end

end