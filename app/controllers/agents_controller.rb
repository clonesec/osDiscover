class AgentsController < ApplicationController

  # ensure user is signed in via Devise
  before_filter :authenticate_user!

  before_filter :redirect_to_root, only: [:edit, :update]

  # use 'execute around' to set up openvas connection for all methods:
  before_filter :openvas_connect_and_login
  after_filter  :openvas_logout

  def index
    @agents = Agent.all(current_user)
  end

  def show
    @agent = Agent.find(params[:id], current_user)
  end

  def new
    @agent = Agent.new
    @agent.persisted = false
  end

  def create
    @agent = Agent.new(params[:agent])
    @agent.persisted = false
    if @agent.save(current_user)
      redirect_to agents_url, notice: "Successfully created agent."
    else
      render action: 'new'
    end
  end

  def edit
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def update
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def destroy
    @agent = Agent.find(params[:id], current_user)
    redirect_to(agents_url, notice: "Unable to find agent #{params[:id]}.") and return if @agent.blank?
    msg = @agent.delete_record(current_user)
    if msg.blank?
      redirect_to agents_url, notice: "Successfully deleted agent."
    else
      redirect_to agents_url, notice: msg
    end
  end

  def verify_agent
    @agent = Agent.find(params[:id], current_user)
    msg = @agent.verify_agent(current_user)
    if msg.blank?
      redirect_to agents_url, notice: "Agent: #{@agent.name} verified."
    else
      redirect_to agents_url, notice: msg
    end
  end

  # GET /download_agent/1
  def download_agent
    agent = Agent.get_agent_with_format(current_user, params[:id], params[:agent_format])
    if agent.package.blank?
      flash[:error] = "Installer package is empty for agent #{agent.name}."
      redirect_to agents_url
    else
      # note: the following does not always yield a value for content_type, so let's default to 'application/octet-stream':
      extname = File.extname(agent.package_filename)[1..-1]
      mime_type = Mime::Type.lookup_by_extension(extname)
      content_type = mime_type.to_s unless mime_type.nil?
      content_type = 'application/octet-stream' if content_type.blank?
      send_data agent.package, type: content_type, filename: "#{agent.package_filename}", disposition: 'attachment'
    end
  end

end