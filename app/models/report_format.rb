class ReportFormat

  include OpenvasModel

  attr_accessor :extension, :content_type, :trust, :trust_time, :description, :parameters, :global
  # for create (i.e. file import):
  attr_accessor :xml_file
  # for editing:
  attr_accessor :name, :summary, :active

  validates :name, :presence => true, :length => { :maximum => 80 }, :on => :update
  validates :summary, :presence => true, :length => { :maximum => 400 }, :on => :update

  def self.selections(user)
    rfs = []
    rf = ReportFormat.new({:id=>'simple', :name=>'Simple Notice'})
    rfs << rf
    self.all(user).each do |rf|
      rfs << rf
    end
    rfs
  end

  def self.format_list(user)
    rfs = []
    self.all(user).each do |rf|
      rfs << rf if rf.active == '1'
    end
    rfs
  end

  def self.find_id_for_name(user, format_name)
    return '' if format_name.blank?
    req = Nokogiri::XML::Builder.new { |xml| xml.get_report_formats }
    formats = user.openvas_connection.sendrecv(req.doc)
    ret = []
    formats.xpath('/get_report_formats_response/report_format').each { |r|
      fmt            = ReportFormat.new
      fmt.id         = extract_value_from("@id", r)
      fmt.name       = extract_value_from("name", r)
      ret << fmt
    }
    ret.each do |f|
      return f.id if f.name.downcase == format_name
    end
    return ''
  end

  def self.all(user, options = {})
    params = {}
    params[:report_format_id] = options[:id] if options[:id]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_report_formats(params) }
    formats = user.openvas_connection.sendrecv(req.doc)
    # Rails.logger.info "formats=#{formats.to_xml.to_yaml}\n\n"
    ret = []
    begin
      formats.xpath('/get_report_formats_response/report_format').each { |r|
        fmt = ReportFormat.new
        fmt.id            = extract_value_from("@id", r)
        fmt.name          = extract_value_from("name", r)
        fmt.extension     = extract_value_from("extension", r)
        fmt.content_type  = extract_value_from("content_type", r)
        fmt.trust         = extract_value_from("trust", r)
        fmt.trust_time    = extract_value_from("trust/time", r)
        fmt.active        = extract_value_from("active", r)
        fmt.summary       = extract_value_from("summary", r)
        fmt.description   = extract_value_from("description", r)
        fmt.parameters    = extract_value_from("parameters", r)
        fmt.global        = extract_value_from("global", r)
        ret << fmt
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def import(user)
    # note that this is so simple let's not use Nokogiri:
    #      also, this xml code is using the "embedded get_report_formats_response element" 
    req = "<create_report_format>" + @xml_file.read + "</create_report_format>"
    # Rails.logger.info "\n req=#{req}\n"
    begin
      resp = user.openvas_connection.sendrecv(req)
      # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
      if ReportFormat.extract_value_from("//@status", resp) =~ /20\d/
        return true
      else
        msg = ReportFormat.extract_value_from("//@status_text", resp)
        errors.add(:openvas, "<br />uploaded file is invalid, reason:<br /><b>" + msg + "</b><br />Note: all imported Report Format files must be based on a valid XML report format file.")
        return false
      end
    rescue Exception => e
      errors[:command_failure] << e.message
      return false
    end
  end

  def self.export(id, user)
    params = { :export=>'1' }
    params[:report_format_id] = id if id
    req = Nokogiri::XML::Builder.new { |xml| xml.get_report_formats(params) }
    rf_as_xml = user.openvas_connection.sendrecv(req.doc)
    rf_as_xml.root.to_s # to remove the <?xml version="1.0"?> from the beginning of the xml doc
  end

  def verify_report_format(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.verify_report_format(:report_format_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = ReportFormat.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + ReportFormat.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

  def save(user)
    self.errors.add(:openvas, "<br />XML file is blank") and return if self.xml_file.blank?
    self.errors.add(:openvas, "<br />XML file is invalid") and return unless self.xml_file.respond_to?(:tempfile)
    self.import(user)
    return false unless self.errors.blank?
    return true
  end

  def update(user)
    if valid?(:update)
      self.update_report_format(user)
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
    update(user)
  end

  def update_report_format(user)
    req = Nokogiri::XML::Builder.new { |xml|
      xml.modify_report_format(:report_format_id => @id) {
        xml.name { xml.text(@name) }
        xml.summary { xml.text(@summary) }
        xml.active  { xml.text(@active) }
      }
    }
    begin
      # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}\n\n"
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      unless ReportFormat.extract_value_from("//@status", resp) =~ /20\d/
        msg = ReportFormat.extract_value_from("//@status_text", resp)
        errors[:command_failure] << msg
        return nil
      end
      true
    rescue Exception => e
      errors[:command_failure] << e.message
      nil
    end
  end

  def delete_record(user)
    return if @id.blank?
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_report_format(:report_format_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = ReportFormat.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + ReportFormat.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end