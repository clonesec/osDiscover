class Note

  include OpenvasModel

  attr_accessor :nvt_oid, :nvt_name, :hosts, :port, :threat, :note_text, :text_excerpt, :orphan
  attr_accessor :creation_time, :modification_time
  attr_accessor :task_id, :task_name
  attr_accessor :result_id, :result_description
  attr_accessor :report_id

  define_attribute_methods [:nvt_oid, :nvt_name, :hosts, :port, :threat, :note_text, :task_id, :result_id, :report_id]

  validates :note_text, :presence => true, :length => { :maximum => 600 }

  def self.parse_result_node(xml)
    nt = Note.new
    nt.id                 = extract_value_from("@id", xml)
    nt.nvt_oid            = extract_value_from("nvt/@oid", xml)
    nt.nvt_name           = extract_value_from("nvt/name", xml)
    nt.hosts              = extract_value_from("hosts", xml)
    nt.hosts              = 'Any' if nt.hosts.blank?
    nt.port               = extract_value_from("port", xml)
    nt.port               = 'Any' if nt.port.blank?
    nt.threat             = extract_value_from("threat", xml)
    nt.threat             = 'Any' if nt.threat.blank?
    nt.note_text          = extract_value_from("text", xml)
    nt.text_excerpt       = extract_value_from("text/@excerpt", xml)
    nt.orphan             = extract_value_from("orphan", xml)
    nt.task_id            = extract_value_from("task/@id", xml)
    nt.task_name          = extract_value_from("task/name", xml)
    nt.task_name          = 'Any' if nt.task_id.blank?
    nt.result_id          = extract_value_from("result/@id", xml)
    nt.result_description = extract_value_from("result/description", xml)
    nt.result_description = 'Any' if nt.result_id.blank?
    nt.creation_time      = extract_value_from("creation_time", xml)
    nt.modification_time  = extract_value_from("modification_time", xml)
    nt
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
    params[:note_id] = options[:id] if options[:id]
    params[:task_id] = options[:task_id] if options[:task_id]
    params[:sort_field] = options[:sort_field] if options[:sort_field]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_notes(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n Note.all >>> resp=#{resp.to_xml.to_yaml}\n\n"
      resp.xpath("/get_notes_response/note").each { |xml|
        ret << Note.parse_result_node(xml)
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def save(user)
    if valid?
      n = Note.find(self.id, user) unless self.id.blank? # for update action
      n = Note.new if n.blank? # for create action
      n.note_text   = self.note_text
      n.task_id     = self.task_id
      n.result_id   = self.result_id
      n.nvt_oid     = self.nvt_oid
      n.hosts       = self.hosts
      n.port        = self.port
      n.threat      = self.threat
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
        xml.modify_note(:note_id => @id) {
          xml.text_   { xml.text(@note_text) }
          xml.hosts   { xml.text(@hosts) }
          xml.port    { xml.text(@port) }
          xml.threat  { xml.text(@threat) }
          xml.result(:id => @result_id)
          xml.task(:id => @task_id)
        }
      else
        xml.create_note {
          xml.text_   { xml.text(@note_text) }
          xml.hosts   { xml.text(@hosts) }
          xml.port    { xml.text(@port) }
          xml.threat  { xml.text(@threat) }
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
      unless Note.extract_value_from("//@status", resp) =~ /20\d/
        msg = Note.extract_value_from("//@status_text", resp)
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
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_note(:note_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = Note.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Note.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end