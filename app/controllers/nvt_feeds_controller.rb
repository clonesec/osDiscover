class NvtFeedsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_oap_connect_and_login
  after_filter :openvas_logout

  def index
    @nvt_feeds = NvtFeed.describe_feed(current_user)
  end

  def sync_feed
    resp = NvtFeed.sync_feed(current_user)
    if NvtFeed.extract_value_from("//@status", resp) =~ /20\d/
      redirect_to feeds_url, notice: "Successfully submitted request to synchronize with NVT feed."
    else
      redirect_to feeds_url, notice: "Error: " + NvtFeed.extract_value_from("//@status_text", resp)
    end
  end

end