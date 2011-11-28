class SystemReport

  include OpenvasModel

  attr_accessor :name, :title, :report

  def self.all(user, options = {})
    params = {}
    params[:name] = options[:name] if options[:name]
    if options[:brief] && options[:brief] == true
      params.merge!({brief: "1"})
    end    
    req = Nokogiri::XML::Builder.new { |xml| xml.get_system_reports(params) }
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      resp.xpath("/get_system_reports_response/system_report").each { |xml|
        rep       = SystemReport.new
        rep.name    = extract_value_from("name", xml)
        rep.title   = extract_value_from("title", xml)
        rep.report  = extract_value_from("report", xml)
        ret << rep
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def self.find(id, user)
    return nil if id.blank? || user.blank?
    f = self.all(user, name:id).first
    return nil if f.blank?
    # ensure "first" has the desired name:
    if f.name == id
      return f
    else
      return nil
    end
  end

end