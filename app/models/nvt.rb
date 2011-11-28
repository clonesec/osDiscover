class Nvt

  include OpenvasModel

  attr_accessor :config_id
  attr_accessor :name, :category, :copyright, :description, :summary, :family, :version, :cvss_base
  attr_accessor :risk_factor, :cve_id, :bugtraq_id, :xrefs, :fingerprints, :tags
  attr_accessor :preference_count, :timeout, :checksum, :algorithm
  # only for editing:
  attr_accessor :selected

  include Comparable
  # note the following methods: <=>, eql?, and hash are used with 'include Comparable' to allow us to customize '.uniq':
  def <=>(other)
    # combined comparison operator:
    # returns  0 if first operand equals second
    # returns  1 if first operand is greater than the second
    # returns -1 if first operand is less than the second
    name_id = name + id
    other_name_id = other.name + other.id
    name_id <=> other_name_id
  end
  
  def eql?(other)
    self.class == other.class && self <=> other
  end
  
  def hash
    id.hash
  end


  def preferences
    @preferences ||= []
  end

  def self.export_preference_file(user, options = {})
    return "config id is missing" if options[:id].blank?
    return "nvt id is missing" if options[:nvt_id].blank?
    return "preference name is missing" if options[:pref_name].blank?
    params = {}
    params[:config_id]  = options[:id]
    params[:nvt_oid]    = options[:nvt_id]
    params[:preference] = options[:pref_name]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_preferences(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    resp = user.openvas_connection.sendrecv(req.doc)
    # Rails.logger.info "\n resp=#{resp.to_xml.to_yaml}\n"
    value = "Error: unable to find the file for preference: #{params[:preference]}"
    value = extract_value_from("/get_preferences_response/preference/value", resp)
    value
  end

  def self.find(options, user)
    return nil if options.blank? || user.blank?
    return nil if options[:id].blank? || options[:config_id].blank?
    f = self.all(user, options).first
    return nil if f.blank?
    # ensure "first" has the desired id:
    if f.id.to_s == options[:id].to_s
      return f
    else
      return nil
    end
    f
  end

  def self.all(user, options = {})
    params = {details: 1}
    params[:sort_order]       = options[:sort_order] if options[:sort_order]
    params[:sort_field]       = options[:sort_field] if options[:sort_field]
    params[:nvt_oid]          = options[:id] if options[:id]
    params[:config_id]        = options[:config_id] if options[:config_id]
    params[:family]           = options[:family] if options[:family]
    params[:timeout]          = 1 if options[:timeout] == 1
    params[:preferences]      = 1 if options[:preferences] == 1
    params[:preference_count] = 1 if options[:preference_count] == 1
    req = Nokogiri::XML::Builder.new { |xml| xml.get_nvts(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n resp=#{resp.to_xml.to_yaml}\n"
      resp.xpath("/get_nvts_response/nvt").each { |xml|
        nvt = Nvt.new
        nvt.config_id         = params[:config_id]
        nvt.selected          = options[:selected] ? true : false
        nvt.id                = extract_value_from("@oid", xml)
        nvt.name              = extract_value_from("name", xml)
        nvt.category          = extract_value_from("category", xml)
        nvt.copyright         = extract_value_from("copyright", xml)
        nvt.description       = extract_value_from("description", xml)
        nvt.summary           = extract_value_from("summary", xml)
        nvt.family            = extract_value_from("family", xml)
        nvt.version           = extract_value_from("version", xml)
        nvt.cvss_base         = extract_value_from("cvss_base", xml)
        nvt.risk_factor       = extract_value_from("risk_factor", xml)
        nvt.cve_id            = extract_value_from("cve_id", xml)
        nvt.bugtraq_id        = extract_value_from("bugtraq_id", xml)
        nvt.xrefs             = extract_value_from("xrefs", xml)
        nvt.fingerprints      = extract_value_from("fingerprints", xml)
        nvt.tags              = extract_value_from("tags", xml)
        nvt.preference_count  = extract_value_from("preference_count", xml)
        nvt.timeout           = extract_value_from("timeout", xml)
        # <checksum><algorithm>md5</algorithm>2397586ea5cd3a69f953836f7be9ef7b</checksum>:
        nvt.checksum          = extract_value_from("checksum", xml)
        nvt.algorithm         = extract_value_from("checksum/algorithm", xml)
        preferences_timeout   = extract_value_from("preferences/timeout", xml)
        xml.xpath("preferences/preference").each { |p|
          # Rails.logger.info "\n\n p=#{p.to_xml.to_yaml}\n\n"
          pref = Preference.new
          pref.nvt_id         = extract_value_from("nvt/@oid", p)
          pref.nvt_name       = extract_value_from("nvt/name", p)
          pref.name           = extract_value_from("name", p)
          pref.val_type_desc  = extract_value_from("type", p)
          pref.value          = extract_value_from("value", p)
          pref.timeout        = preferences_timeout
          nvt.preferences << pref
          # note that <value> isn't included in the <alt>(s), so let's add it as a selectable value:
          pref.preference_values << PreferenceSelect.new({id:pref.value, name:pref.value})
          if pref.val_type_desc.downcase == 'checkbox'
            yes_or_no = pref.value.downcase == 'yes' ? 'no' : 'yes'
            pref.preference_values << PreferenceSelect.new({id:yes_or_no, name:yes_or_no})
          end
          p.xpath("alt").each { |alt| pref.preference_values << PreferenceSelect.new({id:alt.text, name:alt.text}) }
        }
        ret << nvt
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def self.find_by_family(user, options = {})
    return nil if user.blank?
    return nil if options[:family].blank?
    f = self.all_xml_only(user, options)
    return nil if f.blank?
    f
  end

  def self.find_by_config_id_and_family(user, options = {})
    return nil if user.blank?
    return nil if options[:config_id].blank? || options[:family].blank?
    f = self.all_xml_only(user, options)
    return nil if f.blank?
    f
  end

  def self.all_xml_only(user, options = {})
    params = {details: 1}
    params[:sort_order]       = options[:sort_order] if options[:sort_order]
    params[:sort_field]       = options[:sort_field] if options[:sort_field]
    params[:nvt_oid]          = options[:id] if options[:id]
    params[:config_id]        = options[:config_id] if options[:config_id]
    params[:family]           = options[:family] if options[:family]
    params[:timeout]          = 1 if options[:timeout] == 1
    params[:preferences]      = 1 if options[:preferences] == 1
    params[:preference_count] = 1 if options[:preference_count] == 1
    req = Nokogiri::XML::Builder.new { |xml| xml.get_nvts(params) }
    # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n resp=#{resp.to_xml.to_yaml}\n"
      resp.xpath("/get_nvts_response/nvt").each { |xml|
        # add a new element to this node called 'selected', so we can set this nvt as selected or not:
        Nokogiri::XML::Builder.with(xml) do |node|
          value = options[:selected] ? true : false
          node.selected value
        end
        # note creating 1,000's of Nvt objects is very time consuming, so let's try to work with the Nokogiri XML objects instead:
        ret << xml
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def save(user)
    # note only modify(edit/update) via modify_config is implemented in OMP 2.0
    if valid?
      esc = Nvt.new
      esc.name = self.name
      esc.create_or_update(user)
      esc.errors.each do |attribute, msg|
        self.errors.add(:openvas, "<br />" + msg)
      end
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def create_or_update(user)
    # note only modify(edit/update) via modify_config is implemented in OMP 2.0
    req = Nokogiri::XML::Builder.new { |xml|
      xml.modify_config {
        xml.name { xml.text(@name) }
      }
    }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      unless Nvt.extract_value_from("//@status", resp) =~ /20\d/
        msg = Nvt.extract_value_from("//@status_text", resp)
        errors[:command_failure] << msg
        return nil
      end
      true
    rescue Exception => e
      errors[:command_failure] << e.message
      nil
    end
  end

end