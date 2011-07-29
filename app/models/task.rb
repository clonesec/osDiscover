class Task

  include OpenvasModel

  attr_accessor :name, :comment, :overall_progress, :status, :trend, :threat,
                :config_id, :config_name, :target_id, :target_name, :finished_reports_count,
                :escalator_id, :escalator_name,
                :schedule_id, :schedule_name,
                :slave_id, :slave_name,
                :first_report_id, :first_report_date,
                :last_report_id, :last_report_date,
                :last_report_debug, :last_report_high, :last_report_low, :last_report_log, :last_report_medium,
                :finished_reports_count, :reports_count

  validates :comment, :length => { :maximum => 400 }
  validates :name, :presence => true, :length => { :maximum => 80 }

  def reports
    @reports ||= []
  end

  def self.version(user)
    # req = Nokogiri::XML::Builder.new { |xml| xml.get_version }
    # resp = user.openvas_connection.sendrecv(req.doc)
    # note this is an example of how to send multiple commands to openvas (helps avoid sending mulitiple commands via socket):
    req = Nokogiri::XML::Builder.new { |xml|
      xml.commands {
        xml.get_version
        # xml.get_version
        # xml.get_agents
      }
    }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    resp = user.openvas_connection.sendrecv(req.doc)
    # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"

    # how to parse the results of sending multiple commands:
    # from the OMP doc for <commands>:
    # "The client uses the commands command to run a list of commands.
    #  The elements are executed as OMP commands in the given sequence.
    #  The reply contains the result of each command, in the same order as the given commands."
    # note that relying on the results to be in a certain order seems risky, but with that assumption,
    # here is how to parse multiple commands (with the same response name):
    # resp.xpath("/commands_response/get_version_response").each { |xr|
    #   Rails.logger.info "xr=#{xr.to_xml.to_yaml}\n\n"
    # }

    ret = extract_value_from("/commands_response/get_version_response/version", resp)
    ret
  end

  def self.from_xml_node(node)
    t = Task.new
    t.id                      = extract_value_from("@id", node)
    t.name                    = extract_value_from("name", node)
    t.comment                 = extract_value_from("comment", node)
    t.status                  = extract_value_from("status", node)
    t.overall_progress        = extract_value_from("progress", node)

    # note the following counts are assuming this node represents a single task:
    t.finished_reports_count  = extract_value_from("report_count/finished", node).to_i
    report_count              = node.search("report_count")
    ignored                   = report_count.search("finished").remove
    t.reports_count           = report_count.text.to_i

    t.trend                   = extract_value_from("trend", node)
    t.last_report_id          = extract_value_from("last_report/report/@id", node)
    t.last_report_date        = extract_value_from("last_report/report/timestamp", node)
    t.last_report_debug       = extract_value_from("last_report/report/result_count/debug", node).to_i
    t.last_report_high        = extract_value_from("last_report/report/result_count/hole", node).to_i
    t.last_report_low         = extract_value_from("last_report/report/result_count/info", node).to_i
    t.last_report_log         = extract_value_from("last_report/report/result_count/log", node).to_i
    t.last_report_medium      = extract_value_from("last_report/report/result_count/warning", node).to_i
    t.first_report_id         = extract_value_from("first_report/report/@id", node)
    t.first_report_date       = extract_value_from("first_report/report/timestamp", node)
    t.config_id               = extract_value_from("config/@id", node)
    t.config_name             = extract_value_from("config/name", node)
    t.target_id               = extract_value_from("target/@id", node)
    t.target_name             = extract_value_from("target/name", node)
    t.schedule_id             = extract_value_from("schedule/@id", node)
    t.schedule_name           = extract_value_from("schedule/name", node)
    t.slave_id                = extract_value_from("slave/@id", node)
    t.slave_name              = extract_value_from("slave/name", node)
    t.escalator_id            = extract_value_from("escalator/@id", node)
    t.escalator_name          = extract_value_from("escalator/name", node)
    node.xpath("reports/report").each { |r|
      report      = Report.new
      report.id               = extract_value_from("@id", r)
      # report.timestamp        = Time.parse(extract_value_from("timestamp", r))
      report.timestamp        = extract_value_from("timestamp", r)
      report.scan_run_status  = extract_value_from("scan_run_status", r)
      report.can_delete       = status_can_delete(report.scan_run_status)
      report.result_count_total[:debug]  = extract_value_from("result_count/debug", r).to_i
      report.result_count_total[:high]   = extract_value_from("result_count/hole", r).to_i
      report.result_count_total[:low]    = extract_value_from("result_count/info", r).to_i
      report.result_count_total[:log]    = extract_value_from("result_count/log", r).to_i
      report.result_count_total[:medium] = extract_value_from("result_count/warning", r).to_i
      report.result_count_total[:false_positive] = extract_value_from("result_count/false_positive", r).to_i
      report.result_count_total[:total]  = report.result_count_total[:debug] + report.result_count_total[:high] + 
                                           report.result_count_total[:low] + report.result_count_total[:log] + 
                                           report.result_count_total[:medium] + report.result_count_total[:false_positive]
      report.threat_level = report.threat
      t.reports << report
    }
    t
  end

  def self.all(user, options = {})
    params = {}
    params[:details] = options[:details] if options[:details]
    params[:apply_overrides] = options[:apply_overrides] if options[:apply_overrides]
    params[:sort_field] = options[:sort_field] if options[:sort_field]
    params[:sort_order] = options[:sort_order] if options[:sort_order]
    params[:task_id] = options[:id] if options[:id]
    ret = []
    req = Nokogiri::XML::Builder.new { |xml| xml.get_tasks(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      resp.xpath('//task').each { |t| ret << from_xml_node(t) }
    rescue Exception => e
      raise e
    end
    ret
  end

  def self.find(user, params)
    return nil if params[:id].blank? || user.blank?
    f = self.all(user, params).first
    return nil if f.blank?
    # ensure "first" has the desired id:
    if f.id.to_s == params[:id].to_s
      return f
    else
      return nil
    end
  end

  def save(user)
    if valid?
      vt = Task.find(user, {:id=>self.id}) # for update action
      vt = Task.new if vt.blank? # for create action
      vt.name         = self.name
      vt.comment      = self.comment
      vt.schedule_id  = self.schedule_id
      vt.slave_id     = self.slave_id
      vt.escalator_id = self.escalator_id
      # note openvas doesn't allow updates to config_id and target_id, only name and comment:
      if vt.new_record?
        vt.config_id  = self.config_id
        vt.target_id  = self.target_id
      end
      vt.create_or_update(user)
      vt.errors.each do |attribute, msg|
        self.errors.add(:openvas, "<br />" + msg)
      end
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def update_attributes(user, attrs={})
    attrs.each { |key, value|
      send("#{key}=".to_sym, value) if public_methods.include?("#{key}=".to_sym)
    }
    save(user)
  end

  def create_or_update(user)
    req = Nokogiri::XML::Builder.new { |xml|
      if @id
        xml.modify_task(:task_id => @id) {
          xml.name    { xml.text(@name) }
          xml.comment { xml.text(@comment) }
          xml.schedule(:id => @schedule_id) unless @schedule_id.blank? || @schedule_id == '0'
          xml.slave(:id => @slave_id)
          xml.escalator(:id => @escalator_id)
        }
      else
        xml.create_task {
          xml.name    { xml.text(@name) }
          xml.comment { xml.text(@comment) } unless @comment.blank?
          xml.config(:id => @config_id)
          xml.target(:id => @target_id)
          xml.schedule(:id => @schedule_id) unless @schedule_id.blank? || @schedule_id == '0'
          xml.slave(:id => @slave_id) unless @slave_id.blank? || @slave_id == '0'
          xml.escalator(:id => @escalator_id) unless @escalator_id.blank? || @escalator_id == '0'
        }
      end
    }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      @id = Task.extract_value_from("/create_task_response/@id", resp) unless @id
      true
    rescue Exception => e
      errors[:command_failure] << e.message
      nil
    end
  end

  def delete_record(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_task(:task_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
      status = Task.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Task.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

  def threat
		# threat: High, Medium, Low, Log, Debug ... where Log,Debug are shown as None
		return '' if (@last_report_low + @last_report_medium + @last_report_high) == 0
		max = nil
		threat = ''
		low = @last_report_low
		max = low
		threat = 'Low'
		medium = @last_report_medium
		max = medium if medium >= max
		threat = 'Medium' if medium >= max
		high = @last_report_high
		max = high if high >= max
		threat = 'High' if high >= max
		threat = 'None' if threat == 0
		threat
  end

  def start(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.resume_or_start_task(:task_id => @id) }
    user.openvas_connection.sendrecv(req.doc)
  end

  def stop(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.stop_task(:task_id => @id) }
    user.openvas_connection.sendrecv(req.doc)
  end

  def pause(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.pause_task(:task_id => @id) }
    user.openvas_connection.sendrecv(req.doc)
  end

  def resume_paused(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.resume_paused_task(:task_id => @id) }
    user.openvas_connection.sendrecv(req.doc)
  end

  def resume_stopped(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.resume_stopped_task(:task_id => @id) }
    user.openvas_connection.sendrecv(req.doc)
  end

end