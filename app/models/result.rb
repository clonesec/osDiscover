class Result

  include OpenvasModel

  attr_accessor :result_id, :name, :subnet, :host, :port, :nvt_id, :threat, :original_threat, :description
  attr_accessor :task_id

  def notes
    @notes ||= []
  end

  def overrides
    @overrides ||= []
  end

  def self.parse_result_node(node, task_id = nil)
    res = Result.new
    res.id              = extract_value_from("@id", node)
    res.nvt_id          = extract_value_from("nvt/@oid", node)
    res.name            = extract_value_from("nvt/name", node)
    res.port            = extract_value_from("port", node)
    res.threat          = extract_value_from("threat", node)
    res.original_threat = extract_value_from("original_threat", node)
    res.subnet          = extract_value_from("subnet", node)
    res.host            = extract_value_from("host", node)
    res.description     = extract_value_from("description", node)
    res.task_id         = task_id if task_id
    node.xpath("notes/note").each { |note| res.notes << Note.parse_result_node(note) }
    node.xpath("overrides/override").each { |override| res.overrides << Override.parse_result_node(override) }
    res
  end

  def self.find_by_id_and_format(id, format_name, format_id, user)
    options = {}
    # params = {}
    params =  { notes:'1', notes_details:'1', 
                overrides:'1', overrides_details:'1', apply_overrides:'1',
                result_hosts_only:'1'
              }
    params[:levels] = 'hmlgdf' unless options[:levels]
    params[:report_id] = id if id
    params[:format_id] = format_id if format_id
    req = Nokogiri::XML::Builder.new { |xml| xml.get_reports(params) }
    rep = user.openvas_connection.sendrecv(req.doc)
    if format_name == 'xml'
      r = rep.xpath('//get_reports_response/report').to_xml
    else
      r = Base64.decode64(rep.xpath('//get_reports_response/report').text)
    end
    r
  end

  def result_count_total
    unless @result_count_total
      @result_count_total = {total:0, debug:0, log:0, low:0, medium:0, high:0}
    end
    @result_count_total
  end

  def result_count_filtered
    unless @result_count_filtered
      @result_count_filtered = {total:0, debug:0, log:0, low:0, medium:0, high:0}
    end
    @result_count_filtered
  end

end