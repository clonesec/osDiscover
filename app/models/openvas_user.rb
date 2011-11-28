class OpenvasUser

  include OpenvasModel

  attr_accessor :name, :password, :role, :hosts_allow, :hosts_allow_humanized, :hosts

  validates :name,      presence: true, length: { maximum: 80 }
  validates :password,  presence: true, on: :create
  validates :password,  length: { maximum: 40 }

  class Selection
    attr_accessor :id, :name

    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end unless attributes.nil?
    end
  end

  def self.role_selections
    roles = []
    roles << Selection.new({id:'User', name:'User'})
    roles << Selection.new({id:'Admin', name:'Admin'})
    roles
  end

  def self.access_selections
    accesses = []
    accesses << Selection.new({id:'2', name:'Allow All'})
    accesses << Selection.new({id:'1', name:'Allow'})
    accesses << Selection.new({id:'0', name:'Deny'})
    accesses
  end

  def self.all(user, options = {})
    params = {}
    params[:name] = options[:name] if options[:name]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_users(params) }
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      resp.xpath('//user').each { |s|
        u = OpenvasUser.new
        u.id          = extract_value_from("name", s)
        u.name        = extract_value_from("name", s)
        u.role        = extract_value_from("role", s)
        u.hosts_allow = extract_value_from("hosts/@allow", s).to_i
        if u.hosts_allow == 2
          u.hosts_allow_humanized = 'Allow All'
        elsif u.hosts_allow == 1
          u.hosts_allow_humanized = 'Allow:'
        elsif u.hosts_allow == 0
          u.hosts_allow_humanized = 'Deny:'
        end
        u.hosts       = extract_value_from("hosts", s)
        ret << u
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def self.find(name, user)
    return nil if name.blank? || user.blank?
    f = self.all(user, {name:name}).first
    return nil if f.blank?
    # ensure "first" has the desired id:
    if f.name.to_s == name.to_s
      return f
    else
      return nil
    end
  end

  def save(user)
    if valid?
      u = OpenvasUser.find(self.name, user) # for update action
      u = OpenvasUser.new if u.blank? # for create action
      u.name        = self.name
      u.password    = self.password unless self.password.blank?
      u.role        = self.role
      u.hosts_allow = self.hosts_allow
      u.hosts       = self.hosts
      u.create_or_update(user)
      u.errors.each do |attribute, msg|
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
        xml.modify_user {
          xml.name      { xml.text(@name) }
          if self.password.blank?
            xml.password(modify: '0')
          else
            xml.password(modify: '1')  { xml.text(@password) }
          end
          xml.role      { xml.text(@role) }
          # note: GSA defaults to Allow All if the hosts field is blank (seems odd, why not complain at the user?)
          if @hosts_allow == '2' # allow all
            xml.hosts(allow: @hosts_allow)
          elsif @hosts_allow == '1' && !@hosts.blank? # allow + host list
            xml.hosts(allow: @hosts_allow) { xml.text(@hosts) }
          elsif @hosts_allow == '0' && !@hosts.blank? # deny + host list
            xml.hosts(allow: @hosts_allow) { xml.text(@hosts) }
          end
        }
      else
        xml.create_user {
          xml.name        { xml.text(@name) }
          xml.password    { xml.text(@password) }
          xml.role        { xml.text(@role) }
          # note: GSA defaults to Allow All if the hosts field is blank (seems odd, why not complain at the user?)
          if @hosts_allow == '2' # allow all
            xml.hosts(allow: @hosts_allow)
          elsif @hosts_allow == '1' && !@hosts.blank? # allow + host list
            xml.hosts(allow: @hosts_allow) { xml.text(@hosts) }
          elsif @hosts_allow == '0' && !@hosts.blank? # deny + host list
            xml.hosts(allow: @hosts_allow) { xml.text(@hosts) }
          end
        }
      end
    }
    begin
      # Rails.logger.info "\n req.doc=#{req.doc.to_xml.to_yaml}\n"
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n resp=#{resp.to_xml.to_yaml}\n"
      unless OpenvasUser.extract_value_from("//@status", resp) =~ /20\d/
        msg = OpenvasUser.extract_value_from("//@status_text", resp)
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
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_user(name: @name) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = OpenvasUser.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + OpenvasUser.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end