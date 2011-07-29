class SchedulesController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  before_filter :redirect_to_root, :only => [:edit, :update]

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def index
    @schedules = Schedule.all(current_user)
  end

  def show
    @schedule = Schedule.find(params[:id], current_user)
  end

  def new
    @schedule = Schedule.new
    @schedule.persisted = false
  end

  def create
    dt = Time.new(params[:schedule].delete("first_time(1i)").to_i, 
                  params[:schedule].delete("first_time(2i)").to_i,
                  params[:schedule].delete("first_time(3i)").to_i,
                  params[:schedule].delete("first_time(4i)").to_i,
                  params[:schedule].delete("first_time(5i)").to_i)
    params[:schedule][:first_time] = dt
    @schedule = Schedule.new(params[:schedule])
    @schedule.persisted = false
    if @schedule.save(current_user)
      redirect_to(schedules_url, :notice => "Successfully created schedule.")
    else
      render :action => 'new'
    end
  end

  def edit
    @schedule = Schedule.find(params[:id], current_user)
  end

  def update
    @schedule = Schedule.find(params[:id], current_user)
    @schedule.persisted = true
    if @schedule.update_attributes(current_user, params[:schedule])
      redirect_to @schedule, :notice  => "Successfully updated schedule."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @schedule = Schedule.find(params[:id], current_user)
    redirect_to(schedules_url, :notice => "Unable to find schedule #{params[:id]}.") and return if @schedule.blank?
    msg = @schedule.delete_record(current_user)
    if msg.blank?
      redirect_to schedules_url, :notice => "Successfully deleted schedule."
    else
      redirect_to schedules_url, :notice => msg
    end
  end

end