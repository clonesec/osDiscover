class Slave

  include OpenvasModel

  attr_accessor :name, :comment, :host, :port, :login, :password, :in_use
  attr_accessor :task_ids

  validates :comment, :length => { :maximum => 400 }
  validates :name,      :presence => true, :length => { :maximum => 80 }
  validates :host,      :presence => true, :length => { :maximum => 80 }
  validates :port,      :presence => true, :length => { :maximum => 80 }
  validates :login,     :presence => true, :length => { :maximum => 80 }
  validates :password,  :presence => true, :length => { :maximum => 40 }

  def self.selections(user)
    slaves = []
    slave = Slave.new({:id=>'0', :name=>'--'}) # add blank selection, so users can edit Slave selection
    slaves << slave
    self.all(user).each do |s|
      slaves << s
    end
    slaves
  end

  def self.all(user, options = {})
    params = {:tasks => 1}
    params[:slave_id] = options[:id] if options[:id]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_slaves(params) }
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      resp.xpath('//slave').each { |s|
        slave                       = Slave.new
        slave.id                    = extract_value_from("@id", s)
        slave.name                  = extract_value_from("name", s)
        slave.comment               = extract_value_from("comment", s)
        slave.host                  = extract_value_from("host", s)
        slave.port                  = extract_value_from("port", s)
        slave.login                 = extract_value_from("login", s)
        # slave.password              = extract_value_from("password", s)
        slave.in_use                = extract_value_from("in_use", s).to_i
        slave.task_ids = []
        s.xpath('tasks/task/@id') { |t|
          slave.task_ids << t.value
        }
        ret << slave
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def save(user)
    # note modify(edit/update) is not implemented in OMP 2.0
    if valid?
      s = Slave.new
      s.name      = self.name
      s.comment   = self.comment
      s.host      = self.host
      s.port      = self.port
      s.login     = self.login
      s.password  = self.password
      s.create_or_update(user)
      s.errors.each do |attribute, msg|
        self.errors.add(:openvas, "<br />" + msg)
      end
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def update_attributes(attrs={})
    # note modify(edit/update) is not implemented in OMP 2.0
  end

  def create_or_update(user)
    # note modify(edit/update) is not implemented in OMP 2.0
    req = Nokogiri::XML::Builder.new { |xml|
      xml.create_slave {
        xml.name      { xml.text(@name) }
        xml.comment   { xml.text(@comment) } unless @comment.blank?
        xml.host      { xml.text(@host) }
        xml.port      { xml.text(@port) }
        xml.login     { xml.text(@login) }
        xml.password  { xml.text(@password) }
      }
    }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      unless Slave.extract_value_from("//@status", resp) =~ /20\d/
        msg = Slave.extract_value_from("//@status_text", resp)
        errors[:command_failure] << msg
        return nil
      end
      @id = Slave.extract_value_from("/create_slave_response/@id", resp)
      true
    rescue Exception => e
      errors[:command_failure] << e.message
      nil
    end
  end

  def delete_record(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_slave(:slave_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = Slave.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Slave.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end