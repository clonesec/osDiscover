class ReportsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  before_filter :redirect_to_root, :except => [:show, :view_report, :index]

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def index
    options = {} if options.blank?
    options[:details] = '1'
    # note just is case no params are passed, these are the defaults:
    options[:apply_overrides] = '1' if params[:apply_overrides].blank?
    options[:sort_field] = 'name' if params[:sort_field].blank?
    options[:sort_order] = 'ascending' if params[:sort_order].blank?
    # note that to sort by task status the params[:sort_field] should be 'run_status' 
    #      ... this is not documented anywhere in OpenVAS, but it happens to be the database column name
    params.merge!(options)
    @tasks = Task.all(current_user, params)  
  end
  
  def new; end
  def create; end
  def edit; end
  def update; end
  def destroy; end

  def show
    set_default_search_params if params[:search].blank?
    @report = Report.find(params, current_user)
    @formats = ReportFormat.format_list(current_user)
    # FIXME use a presenter here since the report page is complex
  end

  def view_report
    # FIXME use a presenter for this stuff
    # set_default_search_params if params[:search].blank?
    params[:format_name] = 'html' if params[:format_name].blank?
    format_id = ReportFormat.find_id_for_name(current_user, params[:format_name])
    params[:format_id] = format_id
    report = Report.find_by_id_and_format(current_user, params)
    if params[:format_name].downcase == 'html'
      # chop off everything before the body tag (keep the body tag as it has styling):
      b = report.index('<body ', 0)
      @html_body = report[b..report.length] unless b.nil?
      @html_body = report if b.nil?
      render :layout => false
    else
      ext = params[:format_name].downcase
      send_data report, :type => "application/#{ext}", :filename => "report_#{params[:id]}.#{ext}", :disposition => 'attachment'
    end
  end


  private

  def set_default_search_params
    params[:search] = {}
    params[:search][:sort] = 'threat descending'
    params[:search][:apply_overrides] = '1'
    params[:search][:notes] = '1'
    params[:search][:result_hosts_only] = '1'
    params[:search][:cvss] = ''
    params[:search][:search_phrase] = ''
    params[:search][:threat] = {}
    params[:search][:threat][:high] = '1'
    params[:search][:threat][:medium] = '1'
    params[:search][:threat][:low] = '0'
    params[:search][:threat][:log] = '0'
    params[:search][:threat][:fp] = '0'
  end

end