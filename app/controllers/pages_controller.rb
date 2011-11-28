class PagesController < ApplicationController
  before_filter :authenticate_user!, :except => ["monitor"]
  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login, :except => ["monitor"]
  after_filter :openvas_logout, :except => ["monitor"]
  
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
	#@tasks_count = 0
  end 

  def help
    #binding.remote_pry
  end
  
  def monitor
    tmp = `ps aux | grep openvasmd`
    @openvas_manager = tmp.scan("/usr/sbin/openvasmd")
    
    tmp = `ps aux | grep openvassd`
    @openvas_scanner = tmp.scan("openvassd:")
    
    tmp = `ps aux | grep openvasad`
    @openvas_administrator = tmp.scan("/usr/sbin/openvasad")
  end
  
  
  def report_graph
	@days = "{\"text\":\"#{Date.today - 7}\"}, {\"text\":\"#{Date.today - 6}\"}, {\"text\":\"#{Date.today - 5}\"}, {\"text\":\"#{Date.today - 4}\"}, {\"text\":\"#{Date.today - 3}\"}, {\"text\":\"#{Date.today - 2}\"}, {\"text\":\"#{Date.today - 1}\"}"	
	render partial: "/pages/report_graph.json"
  end
	
  def schedule_graph
  	@days = "{\"text\":\"#{Date.today - 7}\"}, {\"text\":\"#{Date.today - 6}\"}, {\"text\":\"#{Date.today - 5}\"}, {\"text\":\"#{Date.today - 4}\"}, {\"text\":\"#{Date.today - 3}\"}, {\"text\":\"#{Date.today - 2}\"}, {\"text\":\"#{Date.today - 1}\"}"	
	render partial: "/pages/schedule_graph.json"
  end
  

  
end
