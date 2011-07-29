class TasksController < ApplicationController

  before_filter :authenticate_user!

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter :openvas_logout

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

  def show
    options = {} if options.blank?
    options[:details] = '1'
    # note default to:
    options[:apply_overrides] = '1' if params[:apply_overrides].blank?
    params.merge!(options)
    @task = Task.find(current_user, params)
    # note these params for Notes and Overrides were copied from the GSA source code:
    note_params = {:task_id=>params[:id], :sort_field=>"notes.nvt, notes.text"}
    @notes = Note.all(current_user, note_params)
    override_params = {:task_id=>params[:id], :sort_field=>"overrides.nvt, overrides.text"}
    @overrides = Override.all(current_user, override_params)
  end

  def new
    @task = Task.new
    @task.persisted = false
  end

  def create
    @task = Task.new(params[:task])
    @task.persisted = false
    if @task.save(current_user)
      redirect_to(@task, :notice => 'Task was successfully created.')
    else
      render :action => "new"
    end
  end

  def edit
    @task = Task.find(current_user, params)
    @task.persisted = true
  end

  def update
    @task = Task.find(current_user, params)
    @task.persisted = true
    if @task.update_attributes(current_user, params[:task])
      redirect_to(tasks_url, :notice => 'Task was successfully updated.')
    else
      render :action => "edit"
    end
  end

  def destroy
    @task = Task.find(current_user, params)
    redirect_to(tasks_url, :notice => "Unable to find task #{params[:id]}.") and return if @task.blank?
    msg = @task.delete_record(current_user)
    if msg.blank?
      redirect_to tasks_url, :notice => "Successfully deleted task."
    else
      redirect_to tasks_url, :notice => msg
    end
  end

  def start_task
    @task = Task.find(current_user, params)
    @task.start(current_user)
    redirect_to(tasks_url)
  end

  def pause_task
    @task = Task.find(current_user, params)
    @task.pause(current_user)
    redirect_to(tasks_url)
  end

  def resume_paused_task
    @task = Task.find(current_user, params)
    @task.resume_paused(current_user)
    redirect_to(tasks_url)
  end

  def stop_task
    @task = Task.find(current_user, params)
    @task.stop(current_user)
    redirect_to(tasks_url)
  end

  def resume_stopped_task
    @task = Task.find(current_user, params)
    @task.resume_stopped(current_user)
    redirect_to(tasks_url)
  end

end