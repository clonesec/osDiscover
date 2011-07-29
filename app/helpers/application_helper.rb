module ApplicationHelper

  def session_timeout_in
    # Time.zone = 'Eastern Time (US & Canada)'
    # current_user.class.timeout_in.ago.in_time_zone.strftime("%a %b %d, %Y %H:%M:%S %Z")
    timeout = Time.now.utc + current_user.class.timeout_in
    timeout.strftime("%a %b %d, %Y %I:%M:%S %P %Z")
  end

end