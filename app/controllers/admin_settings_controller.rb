class AdminSettingsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_oap_connect_and_login
  after_filter :openvas_logout

  def index
    @settings = AdminSettings.scanner_settings(current_user)
  end

end