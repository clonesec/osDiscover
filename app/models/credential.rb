class Credential

  include OpenvasModel

  attr_accessor :name, :login, :comment, :password_type, :password, :in_use, :package_format

  define_attribute_methods [:name, :login, :comment, :password_type, :password, :in_use, :package_format]

  validates :name,      presence: true, length: { maximum: 80 }
  validates :password,  length: { maximum: 40 }
  validates :comment,   length: { maximum: 400 }
  validates :login,     length: { maximum: 80 }

  class OpenvasModelAttributes
    attr_accessor :name, :value, :datatype

    def initialize(attributes = {})
      attributes.each do |n, v|
        send("#{n}=", v)
      end unless attributes.nil?
    end
  end

  def attributes
    a = Hash.new
    a['name']     = OpenvasModelAttributes.new({name:'name', value:self.name, datatype:'string'})
    a['comment']  = OpenvasModelAttributes.new({name:'comment', value:self.comment, datatype:'text'})
    a['login']    = OpenvasModelAttributes.new({name:'login', value:self.login, datatype:'string'})
    a['password'] = OpenvasModelAttributes.new({name:'password', value:self.password, datatype:'password'})
    a
  end

  def scan_targets
    @scan_targets ||= []
  end

  def self.selections(user)
    credentials = []
    cred = Credential.new({id:'0', name:'--'}) # add blank selection, so users can edit Credential selection
    credentials << cred
    self.all(user).each do |c|
      credentials << c
    end
    credentials
  end

  def self.find_public_key_for_id(id, user)
    params = {}
    params[:lsc_credential_id] = id if id
    params[:format] = 'key'
    req = Nokogiri::XML::Builder.new { |xml| xml.get_lsc_credentials(params) }
    rep = user.openvas_connection.sendrecv(req.doc)
    r = rep.xpath('//get_lsc_credentials_response/lsc_credential/public_key').text
    r
  end

  def self.find_format_for_id(id, user, format='key')
    params = {}
    params[:lsc_credential_id] = id if id
    params[:format] = format
    req = Nokogiri::XML::Builder.new { |xml| xml.get_lsc_credentials(params) }
    resp = user.openvas_connection.sendrecv(req.doc)
    r = Base64.decode64(resp.xpath('//get_lsc_credentials_response/lsc_credential/package').text)
    r
  end

  def self.all(user, options = {})
    params = {}
    params[:lsc_credential_id] = options[:id] if options[:id]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_lsc_credentials(params) }
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      resp.xpath("/get_lsc_credentials_response/lsc_credential").each { |xml|
        crd = Credential.new
        crd.id             = extract_value_from("@id", xml)
        crd.name           = extract_value_from("name", xml)
        crd.login          = extract_value_from("login", xml)
        crd.password_type  = extract_value_from("type", xml)
        # crd.password      = extract_value_from("password", xml) # is not returned!
        crd.comment        = extract_value_from("comment", xml)
        crd.in_use         = extract_value_from("in_use", xml).to_i
        crd.package_format = extract_value_from("package/format", xml)
        xml.xpath("targets/target").each { |t|
          st      = ScanTarget.new
          st.id   = extract_value_from("@id", t)
          st.name = extract_value_from("name", t)
          crd.scan_targets << st
        }
        ret << crd
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def save(user)
    if valid?
      c = Credential.find(self.id, user) # for update action
      c = Credential.new if c.blank? # for create action
      c.name      = self.name
      c.comment   = self.comment
      c.login     = self.login
      c.password  = self.password
      c.create_or_update(user)
      c.errors.each do |attribute, msg|
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
        xml.modify_lsc_credential(lsc_credential_id: @id) {
          xml.name      { xml.text(@name) }
          xml.comment   { xml.text(@comment) }
          xml.login     { xml.text(@login) }    unless @password_type.downcase == 'gen'
          xml.password  { xml.text(@password) } unless @password_type.downcase == 'gen'
        }
      else
        xml.create_lsc_credential {
          xml.name      { xml.text(@name) }
          xml.comment   { xml.text(@comment) }  unless @comment.blank?
          xml.login     { xml.text(@login) }    unless @login.blank?
          xml.password  { xml.text(@password) } unless @password.blank?
        }
      end
    }
    begin
      # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}\n\n"
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      unless Credential.extract_value_from("//@status", resp) =~ /20\d/
        msg = Credential.extract_value_from("//@status_text", resp)
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
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_lsc_credential(lsc_credential_id: @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = Credential.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Credential.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end