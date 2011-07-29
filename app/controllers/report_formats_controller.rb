class ReportFormatsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def export_report_format
    export = ReportFormat.export(params[:id], current_user)
    send_data export, :type => "application/xml", :filename => "report_format_#{params[:id]}.xml", :disposition => 'attachment'
  end

  def verify_report_format
    rf = ReportFormat.find(params[:id], current_user)
    msg = rf.verify_report_format(current_user)
    if msg.blank?
      redirect_to report_formats_url, :notice => "Report Format: #{rf.name} verified."
    else
      redirect_to report_formats_url, :alert => msg
    end
  end

  def index
    @report_formats = ReportFormat.all(current_user)
  end

  def show
    @report_format = ReportFormat.find(params[:id], current_user)
  end

  def new
    @report_format = ReportFormat.new
    @report_format.persisted = false
  end

  def create
    @report_format = ReportFormat.new(params[:report_format])
    @report_format.persisted = false
    if @report_format.save(current_user)
      redirect_to report_formats_url, :notice => "Successfully imported report format."
    else
      render :action => 'new'
    end
  end

  def edit
    @report_format = ReportFormat.find(params[:id], current_user)
    @report_format.persisted = true
  end

  def update
    @report_format = ReportFormat.find(params[:id], current_user)
    @report_format.persisted = true
    if @report_format.update_attributes(current_user, params[:report_format])
      redirect_to report_formats_url, :notice  => "Successfully updated report format."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @report_format = ReportFormat.find(params[:id], current_user)
    redirect_to(report_formats_url, :notice => "Unable to find report format #{params[:id]}.") and return if @report_format.blank?
    msg = @report_format.delete_record(current_user)
    if msg.blank?
      redirect_to report_formats_url, :notice => "Successfully deleted report format."
    else
      redirect_to report_formats_url, :notice => msg
    end
  end

end