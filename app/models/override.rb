class Override

  include OpenvasModel

  attr_accessor :nvt_oid, :nvt_name, :hosts, :port, :threat, :override_text, :text_excerpt, :orphan
  attr_accessor :creation_time, :modification_time
  attr_accessor :task_id, :task_name
  attr_accessor :result_id, :result_description
  attr_accessor :report_id
  attr_accessor :new_threat

  define_attribute_methods [:nvt_oid, :nvt_name, :hosts, :port, :threat, :override_text, :task_id, :result_id, :report_id]

  validates :override_text, :presence => true, :length => { :maximum => 600 }

  def self.threat_selections
    threats = []
    threats << Selection.new({:id=>'False Positive', :name=>'False Positive'})
    threats << Selection.new({:id=>'High', :name=>'High'})
    threats << Selection.new({:id=>'Medium', :name=>'Medium'})
    threats << Selection.new({:id=>'Low', :name=>'Low'})
    threats << Selection.new({:id=>'Log', :name=>'Log'})
    threats
  end

  def self.parse_result_node(xml)
    ovr = Override.new
    ovr.id                  = extract_value_from("@id", xml)
    ovr.nvt_oid             = extract_value_from("nvt/@oid", xml)
    ovr.nvt_name            = extract_value_from("nvt/name", xml)
    ovr.hosts               = extract_value_from("hosts", xml)
    ovr.hosts               = 'Any' if ovr.hosts.blank?
    ovr.port                = extract_value_from("port", xml)
    ovr.port                = 'Any' if ovr.port.blank?
    ovr.new_threat          = extract_value_from("new_threat", xml)
    ovr.threat              = extract_value_from("threat", xml)
    ovr.threat              = 'Any' if ovr.threat.blank?
    ovr.override_text       = extract_value_from("text", xml)
    ovr.text_excerpt        = extract_value_from("text/@excerpt", xml)
    ovr.orphan              = extract_value_from("orphan", xml)
    ovr.task_id             = extract_value_from("task/@id", xml)
    ovr.task_name           = extract_value_from("task/name", xml)
    ovr.task_name           = 'Any' if ovr.task_id.blank?
    ovr.result_id           = extract_value_from("result/@id", xml)
    ovr.result_description  = extract_value_from("result/description", xml)
    ovr.result_description  = 'Any' if ovr.result_id.blank?
    ovr.creation_time       = extract_value_from("creation_time", xml)
    ovr.modification_time   = extract_value_from("modification_time", xml)
    ovr
  end

  class Selection
    attr_accessor :id, :name
    def initialize(attributes = {})
      attributes.each { |name, value| send("#{name}=", value) } unless attributes.nil?
    end
  end

  def self.two_selections(second_id, second_name)
    s = []
    s << Selection.new({:id=>'', :name=>'Any'})
    unless second_id.blank?
      if second_name.blank?
        s << Selection.new({:id=>second_id, :name=>second_id})
      else
        s << Selection.new({:id=>second_id, :name=>second_name})
      end
    end
    s
  end

  def self.all(user, options = {})
    params = {:details => "1", :result => "1"}
    params[:override_id] = options[:id] if options[:id]
    params[:task_id] = options[:task_id] if options[:task_id]
    params[:sort_field] = options[:sort_field] if options[:sort_field]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_overrides(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      resp.xpath("/get_overrides_response/override").each { |xml|
        ret << Override.parse_result_node(xml)
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def save(user)
    if valid?
      n = Override.find(self.id, user) unless self.id.blank? # for update action
      n = Override.new if n.blank? # for create action
      n.override_text = self.override_text
      n.task_id       = self.task_id
      n.result_id     = self.result_id
      n.nvt_oid       = self.nvt_oid
      n.hosts         = self.hosts
      n.port          = self.port
      n.threat        = self.threat
      n.new_threat    = self.new_threat
      n.create_or_update(user)
      n.errors.each do |attribute, msg|
        self.errors.add(:openvas, "<br />" + msg)
      end
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def update_attributes(user, attrs={})
    attrs.each { |key, value| send("#{key}=".to_sym, value) if public_methods.include?("#{key}=".to_sym) }
    save(user)
  end

  def create_or_update(user)
    req = Nokogiri::XML::Builder.new { |xml|
      if @id
        xml.modify_override(:override_id => @id) {
          xml.text_       { xml.text(@override_text) }
          xml.hosts       { xml.text(@hosts) }
          xml.port        { xml.text(@port) }
          xml.threat      { xml.text(@threat) }
          xml.new_threat  { xml.text(@new_threat) }
          xml.result(:id => @result_id)
          xml.task(:id => @task_id)
        }
      else
        xml.create_override {
          xml.text_       { xml.text(@override_text) }
          xml.hosts       { xml.text(@hosts) }
          xml.port        { xml.text(@port) }
          xml.threat      { xml.text(@threat) }
          xml.new_threat  { xml.text(@new_threat) }
          xml.nvt(:oid => @nvt_oid)
          xml.result(:id => @result_id)
          xml.task(:id => @task_id)
        }
      end
    }
    begin
      # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}"
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
      unless Override.extract_value_from("//@status", resp) =~ /20\d/
        msg = Override.extract_value_from("//@status_text", resp)
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
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_override(:override_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = Override.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Override.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end