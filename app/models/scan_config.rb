class ScanConfig

  include OpenvasModel

  attr_accessor :name, :comment, :family_count, :families_grow, :nvts_count, :nvts_grow, :in_use
  attr_accessor :tasks, :copy_id, :value, :xml_file
  # only for editing:
  attr_accessor :update_type, :family, :nvt_id, :nvt_values, :scanner_values, :selects, :trends

  validates :name, :presence => true, :length => { :maximum => 80 }, :on => :create
  validates :comment, :length => { :maximum => 400 }, :on => :create
  validates :id, :presence => true, :on => :update

  def tasks
    @tasks ||= []
  end

  def nvt_preferences
    @nvt_preferences ||= []
  end

  def scanner_preferences
    @scanner_preferences ||= []
  end

  def families
    @families ||= {}
  end

  class Selection
    attr_accessor :id, :name

    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end unless attributes.nil?
    end
  end

  def self.base_selections
    cfgs = []
    cfgs << Selection.new({:id=>'085569ce-73ed-11df-83c3-002264764cea', :name=>'Empty, static and fast'})
    cfgs << Selection.new({:id=>'daba56c8-73ec-11df-a475-002264764cea', :name=>'Full and fast'})
    cfgs
  end

  def self.selections(user)
    return nil if user.nil?
    cfgs = []
    self.all(user).each do |o|
      cfgs << o unless o.name == 'empty' # ignore the 'empty'(base) scan config
    end
    cfgs
  end

  def import(user)
    # note that this is so simple let's not use Nokogiri:
    #      also, this xml code is using the "embedded get_configs response element" 
    #      from a previous export to create a scan config:
    req = "<create_config>" + @xml_file.read + "</create_config>"
    # Rails.logger.info "\n req=#{req}\n"
    begin
      resp = user.openvas_connection.sendrecv(req)
      # Rails.logger.info "resp=#{resp.inspect}\n\n"
      if ScanConfig.extract_value_from("//@status", resp) =~ /20\d/
        return true
      else
        msg = ScanConfig.extract_value_from("//@status_text", resp)
        errors.add(:openvas, "<br />uploaded file is invalid, reason:<br /><b>" + msg + "</b><br />Note: all imported Scan Config files must be based on a previous <em>get_configs_response</em> element (i.e. an export).")
        return false
      end
    rescue Exception => e
      errors[:command_failure] << e.message
      return false
    end
  end

  def self.export(id, user)
    params = { :export=>'1' }
    params[:config_id] = id if id
    req = Nokogiri::XML::Builder.new { |xml| xml.get_configs(params) }
    config_as_xml = user.openvas_connection.sendrecv(req.doc)
    config_as_xml.root.to_s # to remove the <?xml version="1.0"?> from the beginning of the xml doc
  end

  def nvt_families(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.get_nvt_families }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      resp.xpath("/get_nvt_families_response/families/family").each { |xml|
        fam               = Family.new
        fam.name          = ScanConfig.extract_value_from("name", xml)
        fam.max_nvt_count = ScanConfig.extract_value_from("max_nvt_count", xml).to_i
        fam.nvt_count     = 0
        fam.growing       = 0
        self.families[fam.name] = fam
      }
    rescue Exception => e
      raise e
    end
  end

  def self.all(user, options = {})
    params = {:sort_field  => "name"}
    if options[:show_details] && options[:show_details] == true
      params.merge!({:families => "1", :preferences => "1"})
    else
      params[:families]     = options[:families] if options[:families]
      params[:preferences]  = options[:preferences] if options[:preferences]
    end    
    params[:config_id] = options[:id] if options[:id]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_configs(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      resp.xpath("/get_configs_response/config").each { |xml|
        cfg               = ScanConfig.new
        cfg.id            = extract_value_from("@id", xml)
        cfg.name          = extract_value_from("name", xml)
        cfg.comment       = extract_value_from("comment", xml)
        cfg.family_count  = extract_value_from("family_count", xml).to_i
        cfg.families_grow = extract_value_from("family_count/growing", xml).to_i
        cfg.nvts_count    = extract_value_from("nvt_count", xml).to_i
        cfg.nvts_grow     = extract_value_from("nvt_count/growing", xml).to_i
        cfg.in_use        = extract_value_from("in_use", xml).to_i
        xml.xpath("tasks/task").each { |t|
          task      = Task.new
          task.id   = extract_value_from("@id", t)
          task.name = extract_value_from("name", t)
          cfg.tasks << task
        }
        xml.xpath("preferences/preference").each { |p|
          pref = Preference.new
          pref.config_id      = cfg.id
          pref.nvt_id         = extract_value_from("nvt/@oid", p)
          pref.nvt_name       = extract_value_from("nvt/name", p)
          pref.name           = extract_value_from("name", p)
          pref.val_type_desc  = extract_value_from("type", p)
          pref.value          = extract_value_from("value", p)
          if pref.nvt_name.blank?
            cfg.scanner_preferences << pref
          else
            cfg.nvt_preferences << pref
            # note the <value> and <alt>(s) in this example preference, which seems to only occur for radio type form fields:
            # <preference>
            #   <nvt oid="1.3.6.1.4.1.25623.1.0.80109">
            #     <name>w3af (NASL wrapper)</name>
            #   </nvt>
            #   <name>Profile</name>
            #   <type>radio</type>
            #   <value>fast_scan</value>
            #   <alt>sitemap</alt>
            #   <alt>web_infrastructure</alt>
            #   <alt>OWASP_TOP10</alt>
            #   <alt>audit_high_risk</alt>
            #   <alt>bruteforce</alt>
            #   <alt>full_audit</alt>
            # </preference>
            # note that <value> isn't included in the <alt>(s), so let's add it as a selectable value:
            pref.preference_values << PreferenceSelect.new({:id=>pref.value, :name=>pref.value})
            if pref.val_type_desc.downcase == 'checkbox'
              yes_or_no = pref.value.downcase == 'yes' ? 'no' : 'yes'
              pref.preference_values << PreferenceSelect.new({:id=>yes_or_no, :name=>yes_or_no})
            end
            p.xpath("alt").each { |alt| pref.preference_values << PreferenceSelect.new({:id=>alt.text, :name=>alt.text}) }
          end
        }
        cfg.nvt_families(user) if options[:families] || options[:show_details] == true
        xml.xpath("families/family").each { |f|
          family = Family.new
          family.name           = extract_value_from('name', f)
          family.nvt_count      = extract_value_from('nvt_count', f).to_i
          family.max_nvt_count  = extract_value_from('max_nvt_count', f).to_i
          family.growing        = extract_value_from("growing", f).to_i
          # cfg.families << family
          cfg.families[family.name] = family
        }
        ret << cfg
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def self.find(params, user)
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

  def update_attributes(user, attrs={})
    attrs.each { |key, value|
      send("#{key}=".to_sym, value) if public_methods.include?("#{key}=".to_sym)
    }
    # note update type may be nvt, scanner, family, or family_nvts
    return nvt_update(user)         if self.update_type == 'nvt'
    return scanner_update(user)     if self.update_type == 'scanner'
    return family_update(user)      if self.update_type == 'family'
    return family_nvts_update(user) if self.update_type == 'family_nvts'
    false
  end

  def family_nvts_update(user)
    if valid?(:update)
      family_nvts_update_openvas(user)
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def family_nvts_update_openvas(user)
    config_id = @id
      req = Nokogiri::XML::Builder.new { |xml|
        xml.modify_config(:config_id => config_id) {
          xml.nvt_selection {
            xml.family { xml.text(@family) }
            @selects.each do |ky, val|
              xml.nvt(:oid => ky) unless val == '0'
            end
          }
        }
      }
      begin
        # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}"
        resp = user.openvas_connection.sendrecv(req.doc)
        # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
        if ScanConfig.extract_value_from("//@status", resp) =~ /20\d/
          true
        else
          msg = ScanConfig.extract_value_from("//@status_text", resp)
          raise msg
        end
      rescue Exception => e
        errors[:command_failure] << e.message
        nil
      end
  end

  def family_update(user)
    if valid?(:update)
      family_update_openvas(user)
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def family_update_openvas(user)
    config_id = @id
      req = Nokogiri::XML::Builder.new { |xml|
        xml.modify_config(:config_id => config_id) {
          xml.family_selection {
            xml.growing  { xml.text(@families_grow) }
            # note that we're assuming that @selects and @trends mirror each other; i.e. every family has both
            @selects.each do |ky, val|
              xml.family {
                xml.name    { xml.text(ky) }
                xml.all     { xml.text(val) }
                xml.growing { xml.text(@trends[ky]) }
              }
            end
          }
        }
      }
      begin
        # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}"
        resp = user.openvas_connection.sendrecv(req.doc)
        # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
        if ScanConfig.extract_value_from("//@status", resp) =~ /20\d/
          true
        else
          msg = ScanConfig.extract_value_from("//@status_text", resp)
          raise msg
        end
      rescue Exception => e
        errors[:command_failure] << e.message
        nil
      end
  end

  def scanner_update(user)
    if valid?(:update)
      scanner_update_openvas(user)
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def scanner_update_openvas(user)
    # note openvas only accepts one preference at a time to modify
    config_id = @id
    @scanner_values.each do |ky, val|
      next if (ky =~ /\~file\^/) && !val.respond_to?(:tempfile)
      req = Nokogiri::XML::Builder.new { |xml|
        xml.modify_config(:config_id => config_id) {
          xml.preference {
            aname = ky.gsub('~', '[')
            aname.gsub!('^', ']')
            xml.name  { xml.text(aname) }
            if val.respond_to?(:tempfile)
              xml.value { xml.text(Base64.encode64(val.read)) }
            else
              xml.value { xml.text(Base64.encode64(val)) }
            end
          }
        }
      }
      begin
        # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}"
        resp = user.openvas_connection.sendrecv(req.doc)
        # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
        if ScanConfig.extract_value_from("//@status", resp) =~ /20\d/
          return true
        else
          msg = ScanConfig.extract_value_from("//@status_text", resp)
          errors.add(:openvas, "<br />uploaded file is invalid, reason:<br /><b>" + msg + "</b><br />Note: all imported Scan Config files must be based on a previous <em>get_configs_response</em> element (i.e. an export).")
          return false
        end
      rescue Exception => e
        errors[:command_failure] << e.message
        nil
      end
    end
  end

  def nvt_update(user)
    if valid?(:update)
      updated = nvt_update_openvas(user)
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def nvt_update_openvas(user)
    # note openvas only accepts one preference at a time to modify
    config_id = @id
    @nvt_values.each do |ky, val|
      file_uploaded = (ky =~ /\~file\^/) && val.respond_to?(:tempfile)
      # next if (ky =~ /\~file\^/) && !val.respond_to?(:tempfile)
      val = '' if (ky =~ /\~file\^/) && val == '1'
      req = Nokogiri::XML::Builder.new { |xml|
        xml.modify_config(:config_id => config_id) {
          xml.preference {
            xml.nvt(:oid => @nvt_id) unless (ky =~ /\~scanner\^/)
            aname = ky.gsub('~', '[')
            aname.gsub!('^', ']')
            xml.name  { xml.text(aname) }
            if file_uploaded
              xml.value { xml.text(Base64.encode64(val.read)) }
            else
              xml.value { xml.text(Base64.encode64(val)) }
            end
          }
        }
      }
      begin
        # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}"
        resp = user.openvas_connection.sendrecv(req.doc)
        # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
        unless ScanConfig.extract_value_from("//@status", resp) =~ /20\d/
          msg = ScanConfig.extract_value_from("//@status_text", resp)
          if file_uploaded?
            errors.add(:openvas, "<br />uploaded file is invalid, reason:<br /><b>" + msg + "</b><br />Note: all imported Scan Config files must be based on a previous <em>get_configs_response</em> element (i.e. an export).")
          else
            errors.add(:openvas, "<br />" + msg)
          end
          return false
        end
      rescue Exception => e
        errors[:command_failure] << e.message
        nil
      end
    end
  end

  def save(user)
    if self.xml_file
      self.errors.add(:openvas, "<br />XML file is blank") and return if self.xml_file.blank?
      self.errors.add(:openvas, "<br />XML file is invalid") and return unless self.xml_file.respond_to?(:tempfile)
      self.import(user)
      return false unless self.errors.blank?
      return true
    end
    if valid?(:create)
      sc = ScanConfig.new
      sc.name         = self.name
      sc.comment      = self.comment
      sc.copy_id      = self.copy_id
      sc.create_config(user)
      sc.errors.each do |attribute, msg|
        self.errors.add(:openvas, "<br />" + msg)
      end
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def create_config(user)
    req = Nokogiri::XML::Builder.new { |xml|
      xml.create_config {
        xml.name    { xml.text(@name) }
        xml.comment { xml.text(@comment) } unless @comment.blank?
        xml.copy    { xml.text(@copy_id) }
      }
    }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      if ScanConfig.extract_value_from("//@status", resp) =~ /20\d/
        @id = ScanConfig.extract_value_from("/create_config_response/@id", resp)
        true
      else
        msg = ScanConfig.extract_value_from("//@status_text", resp)
        raise msg
      end
    rescue Exception => e
      errors[:command_failure] << e.message
      nil
    end
  end

  def delete_record(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_config(:config_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = ScanConfig.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + ScanConfig.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end