class Report

  include OpenvasModel

  attr_accessor :task_id, :task_name, :started_at, :ended_at, :status
  attr_accessor :timestamp, :scan_run_status, :can_delete, :threat_level
  # for filtering report results:
  attr_accessor :sort, :cvss

  def result_count_total
    unless @result_count_total
      @result_count_total = {:total=>0, :false_positive=>0, :debug=>0, :log=>0, :low=>0, :medium=>0, :high=>0}
    end
    @result_count_total
  end

  def result_count_filtered
    unless @result_count_filtered
      @result_count_filtered = {:total=>0, :false_positive=>0, :debug=>0, :log=>0, :low=>0, :medium=>0, :high=>0}
    end
    @result_count_filtered
  end

  def hosts
    @hosts ||= []
  end

  def hosts_threat_totals
    totals = [0, 0, 0, 0, 0, 0]
    @hosts.each do |h|
  		totals[0] += h.high
  		totals[1] += h.medium
  		totals[2] += h.low
  		totals[3] += h.log
  		totals[4] += h.false_positive
  		totals[5] += h.total
    end
    totals
  end

  def ports
    @ports ||= []
  end

  class Port
    attr_accessor :port, :host, :threat
  end

  def results
    @results ||= []
  end

  class Selection
    attr_accessor :id, :name

    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end unless attributes.nil?
    end
  end

  def self.sort_selections
    sorts = []
    sorts << Selection.new({:id=>'threat descending', :name=>'threat descending'})
    sorts << Selection.new({:id=>'threat ascending',  :name=>'threat ascending'})
    sorts << Selection.new({:id=>'port descending',   :name=>'port descending'})
    sorts << Selection.new({:id=>'port ascending',    :name=>'port ascending'})
    sorts
  end

  def self.cvss_selections
    cvsss = []
    cvsss << Selection.new({:id=>'',     :name=>'None'})
    cvsss << Selection.new({:id=>'10.0', :name=>'10.0'})
    cvsss << Selection.new({:id=>'9.0',  :name=>'9.0'})
    cvsss << Selection.new({:id=>'8.0',  :name=>'8.0'})
    cvsss << Selection.new({:id=>'7.0',  :name=>'7.0'})
    cvsss << Selection.new({:id=>'6.0',  :name=>'6.0'})
    cvsss << Selection.new({:id=>'5.0',  :name=>'5.0'})
    cvsss << Selection.new({:id=>'4.0',  :name=>'4.0'})
    cvsss << Selection.new({:id=>'3.0',  :name=>'3.0'})
    cvsss << Selection.new({:id=>'2.0',  :name=>'2.0'})
    cvsss << Selection.new({:id=>'1.0',  :name=>'1.0'})
    cvsss << Selection.new({:id=>'0.0',  :name=>'0.0'})
    cvsss
  end

  def self.levels(params)
    return 'hm' if params.blank?
    return 'hm' if params[:search].blank?
    return 'hm' if params[:search][:threat].blank?
    levels = ''
    params[:search][:threat].each do |l|
      case l[0]
        when 'high'
          levels += l[1] == '1' ? 'h' : ''
        when 'medium'
          levels += l[1] == '1' ? 'm' : ''
        when 'low'
          levels += l[1] == '1' ? 'l' : ''
        when 'log'
          levels += l[1] == '1' ? 'g' : ''
        when 'debug'
          # levels += l[1] == '1' ? 'd' : ''
        when 'fp'
          levels += l[1] == '1' ? 'f' : ''
      end
    end
    return 'hm' if levels.blank?
    levels
  end

  def self.find(options, user)
    params = { :notes_details=>'1', :overrides=>'1', :overrides_details=>'1' } # can't be changed by user
    params[:levels] = self.levels(options)
    params[:report_id] = options[:id] unless options[:id].blank?
    params.merge!(options)
    f = self.all(user, params).first
    return nil if f.blank?
    # ensure "first" has the desired id:
    if f.id.to_s == params[:report_id].to_s
      return f
    else
      return nil
    end
  end

  def self.find_by_id_and_format(user, options)
    params = { :notes_details=>'1', :overrides=>'1', :overrides_details=>'1' } # can't be changed by user
    params[:report_id] = options[:id] unless options[:id].blank?
    params[:format_id] = options[:format_id] unless options[:format_id].blank?
    full_report = false
    full_report = true if options[:search].blank?
    unless full_report
      full_report = true if options[:search][:threat].blank?
    end
    if full_report
      params[:levels] = 'hmlgdf'
      params[:apply_overrides] = '1'
      params[:notes] = '1'
      params[:result_hosts_only] = '1'
    end
    params[:levels] = self.levels(options) unless full_report # i.e. filtered report
    unless options['search'].blank?
      if options['search']['sort']
        sort = options['search']['sort'].split(' ')
        params[:sort_field] = sort[0]
        params[:sort_order] = sort[1]
      end
      params[:apply_overrides] = options['search']['apply_overrides'] if options['search']['apply_overrides']
      params[:notes] = options['search']['notes'] if options['search']['notes']
      params[:result_hosts_only] = options['search']['result_hosts_only'] if options['search']['result_hosts_only']
      params[:search_phrase] = options['search']['search_phrase'] if options['search']['search_phrase']
      params[:min_cvss_base] = options['search']['cvss'] if options['search']['cvss']
    end
    req = Nokogiri::XML::Builder.new { |xml| xml.get_reports(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    resp = user.openvas_connection.sendrecv(req.doc)
    # Rails.logger.info "\n resp=#{resp.to_xml.to_yaml}\n"
    if options[:format_name] == 'xml'
      r = resp.xpath('//get_reports_response/report').to_xml
    else
      r = Base64.decode64(resp.xpath('//get_reports_response/report').text)
    end
    r
  end

  def self.all(user, options = {})
    params = {}
    params[:report_id] = options[:report_id] if options[:report_id]
    params[:notes_details] = options[:notes_details]
    params[:overrides] = options[:overrides]
    params[:overrides_details] = options[:overrides_details]
    params[:levels] = options[:levels] if options[:levels]
    unless options['search'].blank?
      if options['search']['sort']
        sort = options['search']['sort'].split(' ')
        params[:sort_field] = sort[0]
        params[:sort_order] = sort[1]
      end
      params[:apply_overrides] = options['search']['apply_overrides'] if options['search']['apply_overrides']
      params[:notes] = options['search']['notes'] if options['search']['notes']
      params[:result_hosts_only] = options['search']['result_hosts_only'] if options['search']['result_hosts_only']
      params[:search_phrase] = options['search']['search_phrase'] if options['search']['search_phrase']
      params[:min_cvss_base] = options['search']['cvss'] if options['search']['cvss']
    end
    ret = []
    req = Nokogiri::XML::Builder.new { |xml| xml.get_reports(params) }
    # Rails.logger.info "\n\n req=#{req.to_xml.to_yaml}\n\n"
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      # Rails.logger.info "\n\n resp.to_xml.length=#{resp.to_xml.length}\n\n"
    rescue Exception => e
      raise e unless e.message =~ /Failed to find/i
      return ret
    end
    resp.xpath('/get_reports_response/report/report').each { |r|
      rep = Report.new
      rep.id          = extract_value_from("@id", r)
      rep.task_id     = extract_value_from("task/@id", r)
      rep.task_name   = extract_value_from("task/name", r)
      rep.task_name   = extract_value_from("task/name", r)
      rep.status      = extract_value_from("scan_run_status", r)
      rep.can_delete  = status_can_delete(rep.status)
      rep.started_at  = extract_value_from("scan_start", r)
      rep.started_at  = Time.parse(rep.started_at) unless rep.started_at.blank?
      rep.ended_at    = extract_value_from("scan_end", r)
      rep.ended_at    = Time.parse(rep.ended_at) unless rep.started_at.blank?
      rep.result_count_total[:total]  = extract_value_from("result_count/full", r).to_i
      rep.result_count_total[:debug]  = extract_value_from("result_count/debug/full", r).to_i
      rep.result_count_total[:high]   = extract_value_from("result_count/hole/full", r).to_i
      rep.result_count_total[:low]    = extract_value_from("result_count/info/full", r).to_i
      rep.result_count_total[:log]    = extract_value_from("result_count/log/full", r).to_i
      rep.result_count_total[:medium] = extract_value_from("result_count/warning/full", r).to_i
      rep.result_count_total[:false_positive] = extract_value_from("result_count/false_positive/full", r).to_i
      rep.result_count_filtered[:total]   = extract_value_from("result_count/filtered", r).to_i
      rep.result_count_filtered[:debug]   = extract_value_from("result_count/debug/filtered", r).to_i
      rep.result_count_filtered[:high]    = extract_value_from("result_count/hole/filtered", r).to_i
      rep.result_count_filtered[:low]     = extract_value_from("result_count/info/filtered", r).to_i
      rep.result_count_filtered[:log]     = extract_value_from("result_count/log/filtered", r).to_i
      rep.result_count_filtered[:medium]  = extract_value_from("result_count/warning/filtered", r).to_i
      rep.result_count_filtered[:false_positive]  = extract_value_from("result_count/false_positive/filtered", r).to_i
      r.search("./ports/port").each do |port|
        p = Port.new
        host      = port.search("host").remove
        threat    = port.search("threat").remove
        p.port    = port.text
        p.host    = host.text
        p.threat  = threat.text
        rep.ports << p
      end
      r.xpath("./results/result").each { |result|
        rep.results << Result.parse_result_node(result)
      }
      # the host summary info are separate xml nodes, but should be like <hosts>...</hosts>:
      # <host_start><host>127.0.0.1</host>Sun Jul 24 08:34:43 2011</host_start>
      # <host_end><host>127.0.0.1</host>Sun Jul 24 08:37:24 2011</host_end>
      # <host_start><host>199.187.124.37</host>Sun Jul 24 08:34:43 2011</host_start>
      # <host_end><host>199.187.124.37</host>Sun Jul 24 08:37:34 2011</host_end>
      r.xpath("./host_start").each { |hs|
        host = hs.search("host").remove
        h = ReportHostResult.new
        h.host = host.text
        h.started_at = hs.text
        h.high = 0
        h.medium = 0
        h.low = 0
        h.log = 0
        h.debug = 0
        h.false_positive = 0
        found = rep.hosts.find { |hf| hf.host == h.host }
        rep.hosts << h if found.nil?
      }
      r.xpath("./host_end").each { |he|
        host_name = he.search("host").remove
        # FIXME there's probably a better way without creating a throw away ReportHostResult object:
        h = ReportHostResult.new
        h.host = host_name.text
        host = rep.hosts.find { |hf| hf.host == h.host }
        host.ended_at = he.text unless host.blank?
      }
      # for each host gather the threat totals: (note: this must be done after rep.results is created)
      rep.hosts.each do |h|
        host_results = rep.results.find_all { |rh| rh.host == h.host }
        host_results.each do |hr|
          next if hr.threat.blank?
          threat_name = hr.threat.downcase.gsub(' ', '_')
          next unless ['high', 'medium', 'low', 'log', 'debug', 'false_positive'].include? threat_name
          # add 1 to a threat count (i.e. high, medium, low, log, debug, false_positive):
          h.send("incr_#{threat_name}=", 1)
        end
      end
      ret << rep
    }
    ret
  end

  def threat
		return 'None' if @result_count_total[:total] == 0
		high_medium_low = @result_count_total[:high] + @result_count_total[:medium] + @result_count_total[:low]
		return 'None' if high_medium_low <= 0
		low = @result_count_total[:low]
		threat = 'Low'
		medium = @result_count_total[:medium]
		if medium > 0
  		threat = 'Medium'
	  end
		high = @result_count_total[:high]
		if high > 0
  		threat = 'High'
	  end
		return 'Low' if threat == 'Log'
		threat
  end

end