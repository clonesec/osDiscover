class SystemReportsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  before_filter :redirect_to_root, :except => [:index, :show]

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def index
    @system_reports = SystemReport.all(current_user, :brief=>true)
  end

  def show
    @system_report = SystemReport.find(params[:id], current_user)
  end

  def new; end
  def create; end
  def edit; end
  def update; end
  def destroy; end

end