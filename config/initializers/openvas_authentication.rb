Warden::Strategies.add(:openvas_authentication_strategy) do

  # see: https://github.com/hassox/warden/wiki/Overview

  def valid?
    true
  end

  # note https://github.com/hassox/warden/wiki/Strategies has a description of the authenticate!, fail!, and success! methods
  def authenticate!
    debug = [true, false].include?(APP_CONFIG[:debug]) ? APP_CONFIG[:debug] : false
    session[:server_down] = false
    session[:admin] = false
    session[:oap_down] = false
    Rails.logger.info "\n\n authenticate! >>>" if debug
    Rails.logger.info "params=#{params.inspect}" if debug
    return fail!('') if params[:controller].blank?
    return fail!('') unless params[:controller] == "devise/sessions"
    return fail!('') if params[:user].blank?
    # user is trying to sign in, i.e. there are params, so let's try to authenticate them:
    return fail!('') if params[:user][:username].blank?
    return fail!('') if params[:user][:password].blank?
    connection = openvas_authenticate(params[:user][:username], params[:user][:password])
    Rails.logger.info "connection=#{connection.inspect}" if debug
    Rails.logger.info "connection is nil, so: throw :warden" if connection.nil? if debug
    throw :warden if connection.nil?
    Rails.logger.info "connection.logged_in?=#{connection.logged_in?.inspect}" if debug
    return fail!(:invalid) unless connection.logged_in?
    # user is logged in via OMP:
    connection.logout # immediately logout user from openvas omp server, as each controller does this using 'execute around'
    Rails.logger.info "connection.logout=#{connection.inspect}" if debug
    connection = nil # not necessary but let's reinforce the idea that we're stateless and no longer need connection
    Rails.logger.info "connection should be nil=#{connection.inspect}" if debug
    user = User.find_by_username(params[:user][:username])
    # Rails.logger.info "user=#{user.inspect}"
    if user.blank?
      Rails.logger.info "user is blank so try to User.create!" if debug
      begin
        user = User.create!(:username=>params[:user][:username], :password=>params[:user][:password])
        Rails.logger.info "create: user=#{user.inspect}" if debug
      rescue
        Rails.logger.info "rescue error during User.create! ... return fail!" if debug
        return fail!(:invalid)
      end
    else
      # note: user's password in openvas may have changed:
      user.password = params[:user][:password]
      user.save(:validate=>false)
      Rails.logger.info "user not blank so update(password may have changed in openvas) user=#{user.inspect}" if debug
    end
    # FIXME: don't cache user's openvas password (somehow)
    # note: Devise encrypts this user's password in the database, but we may need the password 
    #       again in this user's session to authenticate with openvas as we send omp/oap commands
    #       ... so let's cache it (***there has to be a more secure way***)
    Rails.logger.info "caching username/password=#{user.username.inspect}" if debug
    Rails.cache.delete(user.username)
    Rails.cache.write(user.username, user.password)
    # p = Rails.cache.read(user.username)
    # Rails.logger.info "cached password=#{p.inspect}"
    # check to see if this user is an admin by trying to log them in to the OAP server:
    Rails.logger.info "can user log in to OAP?" if debug
    oap_conn = openvas_oap_authenticate(params[:user][:username], params[:user][:password])
    Rails.logger.info "oap_conn=#{oap_conn.inspect}" if debug
    if oap_conn.nil?
      Rails.logger.info "oap_conn.nil?=#{oap_conn.nil?.inspect}" if debug
      session[:oap_down] = true
      Rails.logger.info "session[:oap_down]=#{session[:oap_down].inspect}" if debug
    elsif oap_conn.logged_in?
      Rails.logger.info "oap_conn.logged_in?=#{oap_conn.logged_in?.inspect}" if debug
      session[:admin] = true
      Rails.logger.info "session[:oap_down]=#{session[:oap_down].inspect}" if debug
      oap_conn.logout # immediately logout user from openvas oap server, as each controller does this using 'execute around'
      Rails.logger.info "oap_conn.logout=#{oap_conn.inspect}" if debug
      oap_conn = nil # not necessary but let's reinforce the idea that we're stateless and no longer need oap_conn
      Rails.logger.info "oap_conn should be nil=#{oap_conn.inspect}" if debug
    end
    # note at this point the user is successfully logged in via Warden/Devise and OpenVAS OMP, but
    #      they may have failed the OAP (admin) log in because they are not an admin or the OAP server is down (a common event)
    Rails.logger.info "*** do: Devise success! for user ***" if debug
    success!(user) # causes a halt! ... so make this the last thing done
  end

  def openvas_authenticate(username, password)
    return false if username.blank? or password.blank?
    oc = Openvas::Connection.new("host"=>APP_CONFIG[:openvas_omp_host],"port"=>APP_CONFIG[:openvas_omp_port],"user"=>username,"password"=>password)
    return nil if oc.socket_check.blank?
    oc.login
    oc
  end

  def openvas_oap_authenticate(user, password)
    return false if user.blank? or password.blank?
    oc = Openvas::Connection.new("host"=>APP_CONFIG[:openvas_oap_host],"port"=>APP_CONFIG[:openvas_oap_port],"user"=>user,"password"=>password)
    return nil if oc.socket_check.blank?
    oc.login
    oc
  end

end