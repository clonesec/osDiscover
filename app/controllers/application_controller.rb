load "#{Rails.root}/extras/openvas_connection.rb"

class ApplicationController < ActionController::Base

  include Openvas

  protect_from_forgery

  before_filter :set_back

  layout :layout_by_resource

  def layout_by_resource
    if devise_controller? && resource_name == :user && action_name == 'new'
      "login"
    else
      "application"
    end
  end

  
  private

  def set_back
    user_just_signed_in = request.env['HTTP_REFERER'].index("/users/sign_in") unless request.env['HTTP_REFERER'].blank?
    session[:go_back] = root_url and return if user_just_signed_in
    session[:go_back] = request.env['HTTP_REFERER'] || root_url
  end

  def redirect_to_root
    redirect_to root_url, alert: "Action is not allowed!"
  end

  def sign_out_and_redirect(resource_or_scope)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    if Devise.sign_out_all_scopes
      sign_out_all_scopes
    else
      sign_out(scope)
    end
    redirect_to after_sign_out_path_for(scope)
  end

  # override Devise's sign_out redirect path method:
  def after_sign_out_path_for(resource_or_scope)
    # Rails.logger.info "\n\n resource_or_scope=#{resource_or_scope.inspect}\n\n"
    # scope = Devise::Mapping.find_scope!(resource_or_scope)
    # Rails.logger.info "\n\n scope=#{scope.inspect}\n\n"
    new_user_session_path
  end

  def openvas_connect_and_login
    redirect_to destroy_user_session_url and return if current_user.blank?
    password = Rails.cache.read(current_user.username)
    redirect_to destroy_user_session_url and return if password.blank?
    current_user.openvas_connection = nil
    current_user.openvas_admin = (session[:admin] && !session[:oap_down]) ? true : false
    host = APP_CONFIG[:openvas_omp_host]
    port = APP_CONFIG[:openvas_omp_port]
    and_version = APP_CONFIG[:omp_version_expected]
    connection = Openvas::Connection.new("host"=>host, "port"=>port, "user"=>current_user.username, "password"=>password)
    unless is_valid_omp? connection, and_version
      Rails.logger.info "\n\n********************************************************************************"
      Rails.logger.info "ApplicationController#openvas_connect_and_login ... about to: throw :warden ..."
      Rails.logger.info "host=#{host} | port=#{port}"
      Rails.logger.info "session=#{session.inspect}"
      Rails.logger.info "********************************************************************************\n\n"
      scope = Devise::Mapping.find_scope!(:user)
      if Devise.sign_out_all_scopes
        sign_out_all_scopes
      else
        sign_out(scope)
      end
      # openvas server is unreachable or whatever, and this will destroy the user's session:
      throw :warden
    end
    connection.login
    connection = nil unless connection.logged_in?
    current_user.openvas_connection = connection
  end

  def openvas_oap_connect_and_login
    redirect_to destroy_user_session_url and return if current_user.blank?
    cached_password = Rails.cache.read(current_user.username)
    redirect_to destroy_user_session_url and return if cached_password.blank?
    # note since this is admin related, let's assume the worse (or the safest):
    current_user.openvas_admin = false
    session[:admin] = false
    session[:oap_down] = true
    current_user.openvas_connection = nil
    host = APP_CONFIG[:openvas_oap_host]
    port = APP_CONFIG[:openvas_oap_port]
    and_version = APP_CONFIG[:oap_version_expected]
    connection = Openvas::Connection.new("host"=>host, "port"=>port, "user"=>current_user.username, "password"=>cached_password)
    # note that we don't want to say the OAP server is down just coz this user is not an admin:
    session[:oap_down] = is_oap_down_for? connection
    redirect_to root_url and return unless is_valid_oap? connection, and_version
    current_user.openvas_admin = true
    session[:admin] = true
    current_user.openvas_connection = connection
  end

  def openvas_logout
    return if current_user.blank?
    return if current_user.openvas_connection.blank?
    return if current_user.openvas_connection.socket_check.nil?
    current_user.openvas_connection.logout
  end

  def is_valid_omp?(connection, version)
    return false if connection.nil?
    return false if connection.socket_check.nil?
    unless connection.version.downcase == version.downcase
      Rails.logger.info "\n\n********************************************************************************"
      Rails.logger.info "Error: expected version=#{version.inspect} but found connection.version=#{connection.version.inspect}"
      Rails.logger.info "********************************************************************************\n\n"
      return false
    end
    true
  end

  def is_oap_down_for?(connection)
    return true if connection.nil?
    return true if connection.socket_check.nil?
    # note it would be nice to also check the OAP version here, but we can't because
    # the OAP requires the first command to be authenticate ... but this user may not be an admin
    # i.e. we don't want to say the OAP server is down just coz this user is not an admin
    false
  end

  def is_valid_oap?(connection, version)
    return false if connection.nil?
    return false if connection.socket_check.nil?
    # note for OAP the first command must be authenticate, so let's try to login:
    connection.login
    return false unless connection.logged_in?
    unless connection.version.downcase == version.downcase
      Rails.logger.info "\n\n********************************************************************************"
      Rails.logger.info "Error: expected version=#{version.inspect} but found connection.version=#{connection.version.inspect}"
      Rails.logger.info "********************************************************************************\n\n"
      return false
    end
    true
  end

end