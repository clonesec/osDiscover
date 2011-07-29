class ScanConfigsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  # GET /export_preference_file/1
  def export_preference_file
    export = Nvt.export_preference_file(current_user, params)
    send_data export, :type => 'application/octet-stream', :filename => "pref_file.bin", :disposition => 'attachment'
  end

  # GET /export_config/1
  def export_config
    export = ScanConfig.export(params[:id], current_user)
    send_data export, :type => "application/xml", :filename => "config_#{params[:id]}.xml", :disposition => 'attachment'
  end

  def index
    @scan_configs = ScanConfig.all(current_user)
  end

  def show
    params.merge!({:show_details=>true}) # true will return Families and Preferences
    @scan_config = ScanConfig.find(params, current_user)
    if @scan_config.blank?
      @scan_config = ScanConfig.new
      @scan_config.id = 'unknown'
      @scan_config.name = 'unknown'
      @scan_config.in_use = 0
    end
  end

  def new
    @scan_config = ScanConfig.new
    @scan_config.persisted = false
  end

  def create
    @scan_config = ScanConfig.new(params[:scan_config])
    @scan_config.persisted = false
    if @scan_config.save(current_user)
      redirect_to scan_configs_url, :notice => "Successfully created Scan Config."
    else
      render :action => 'new'
    end
  end

  def edit
    @update_type ||= params[:update_type].downcase
    params.merge!({:preferences=>'1'}) if @update_type == 'scanner'
    params.merge!({:preferences=>'1'}) if @update_type == 'nvt'
    params.merge!({:families=>'1'}) if @update_type == 'family'
    params.merge!({:families=>'1'}) if @update_type == 'family_nvts'
    @scan_config = ScanConfig.find(params, current_user)
    @scan_config.persisted = true
    case @update_type
      when 'nvt'
        with_oid_and_config_id = {:id=>params[:nvt_id], :config_id=>params[:id], :timeout=>1, :preferences=>1, :preference_count=>1}
        @nvt = Nvt.find(with_oid_and_config_id, current_user)
        render 'nvt_edit'
      when 'scanner'
        render 'scanner_edit'
      when 'family'
        render 'family_edit'
      when 'family_nvts'
        @family_nvts = FamilyNvts.get_family_nvts(current_user, @scan_config.id, params[:family])
        render 'family_nvts_edit'
      else
        redirect_to scan_configs_url, :alert => "Scan Config: update type of '#{@update_type}' is unknown!"
    end
  end

  def update
    @update_type = params[:update_type].downcase
    params.merge!({:families=>'1'}) if @update_type == 'family'
    params.merge!({:preferences=>'1'}) if @update_type == 'nvt'
    params.merge!({:preferences=>'1'}) if @update_type == 'scanner'
    @scan_config = ScanConfig.find(params, current_user)
    @scan_config.persisted = true
    if @scan_config.update_attributes(current_user, params)
      redirect_to scan_config_path(@scan_config.id), :notice  => "Successfully updated Scan Config."
    else
      case @update_type
        when 'nvt'
          with_oid_and_config_id = {:id=>params[:nvt_id], :config_id=>params[:id], :timeout=>1, :preferences=>1, :preference_count=>1}
          @nvt = Nvt.find(with_oid_and_config_id, current_user)
          render 'nvt_edit'
        when 'scanner'
          render 'scanner_edit'
        when 'family'
          render 'family_edit'
        when 'family_nvts'
          @family_nvts = FamilyNvts.get_family_nvts(current_user, @scan_config.id, params[:family])
          render 'family_nvts_edit'
        else
          redirect_to scan_configs_url, :alert => "Scan Config: update type of '#{@update_type}' is unknown!"
      end
    end
  end

  def destroy
    @scan_config = ScanConfig.find(params, current_user)
    redirect_to(scan_configs_url, :notice => "Unable to find scan config #{params[:id]}.") and return if @scan_config.blank?
    msg = @scan_config.delete_record(current_user)
    if msg.blank?
      redirect_to scan_configs_url, :notice => "Successfully deleted scan config."
    else
      redirect_to scan_configs_url, :notice => msg
    end
  end

end