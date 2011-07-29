class Agent

  include OpenvasModel

  attr_accessor :name, :comment, :in_use, :trust, :trusted_at
  attr_accessor :installer, :installer_signature
  attr_accessor :package, :package_format, :package_filename

  validates :installer, :presence => true
  validates :name, :presence => true, :length => { :maximum => 80 }
  validates :comment, :length => { :maximum => 400 }

  class Datum
    attr_accessor :data, :name
  end

  def self.get_agent_with_format(user, id, format)
    # note: format can be "installer", "howto_install", "howto_use"
    params = {}
    params[:agent_id] = id
    params[:format] = format
    req = Nokogiri::XML::Builder.new { |xml| xml.get_agents(params) }
    agt = Agent.new
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      resp.xpath("/get_agents_response/agent").each { |xml|
        agt.id                = extract_value_from("@id", xml)
        agt.name              = extract_value_from("name", xml)
        agt.comment           = extract_value_from("comment", xml)
        agt.in_use            = extract_value_from("in_use", xml).to_i
        agt.package_format    = extract_value_from("package/@format", xml)
        agt.package_filename  = extract_value_from("package/filename", xml)
        agt.package           = Base64.decode64(extract_value_from("package", xml))
      }
    rescue Exception => e
      raise e
    end
    agt
  end

  def self.all(user, options = {})
    params = {}
    # params = {:format => "installer"}
    params[:agent_id] = options[:id] if options[:id]
    req = Nokogiri::XML::Builder.new { |xml| xml.get_agents(params) }
    ret = []
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      # Rails.logger.info "\n resp=#{resp.to_xml.to_yaml}\n"
      resp.xpath("/get_agents_response/agent").each { |xml|
        agt = Agent.new
        agt.id          = extract_value_from("@id", xml)
        agt.name        = extract_value_from("name", xml)
        agt.comment     = extract_value_from("comment", xml)
        agt.in_use      = extract_value_from("in_use", xml).to_i
        agt.trust       = extract_value_from("installer/trust", xml)
        ta              = extract_value_from("installer/trust/time", xml)
        agt.trusted_at  = Time.parse(ta) unless ta.blank?
        # agt.escalator_condition = extract_value_from("condition", xml)
        # agt.condition_datas = []
        # xml.search("condition > data").each do |data|
        #   dt = Datum.new
        #   # remove the <name> element from the <data> element, so we can get the <data> text:
        #   name = data.search("name").remove
        #   dt.data = data.text
        #   dt.name = name.text
        #   agt.condition_datas << dt unless dt.name.blank?
        # end
        ret << agt
      }
    rescue Exception => e
      raise e
    end
    ret
  end

  def save(user)
    # note modify(edit/update) is not implemented in OMP 2.0
    if valid?
      agt = Agent.new
      agt.name                = self.name
      agt.comment             = self.comment
      agt.installer           = self.installer
      # typical file upload params:
      # installer"=>#<ActionDispatch::Http::UploadedFile:0x00000102a72bc0 
      #             @original_filename="cls.html", 
      #             @content_type="text/html", 
      #             @headers="Content-Disposition: form-data; name=\"agent[installer]\"; 
      #                       filename=\"cls.html\"\r\nContent-Type: text/html\r\n", 
      #             @tempfile=#<File:/var/folders/FL/FLG5JAoEEYWY0dxvpS-ku++++TI/-Tmp-/RackMultipart20110624-923-1kcz6eg>>}, 
      agt.installer_signature = self.installer_signature
      agt.create_or_update(user)
      agt.errors.each do |attribute, msg|
        self.errors.add(:openvas, "<br />" + msg)
      end
      return false unless self.errors.blank?
      return true
    else
      return false
    end
  end

  def create_or_update(user)
    # note modify(edit/update) is not implemented in OMP 2.0
    req = Nokogiri::XML::Builder.new { |xml|
      xml.create_agent {
        xml.name    { xml.text(@name) }
        xml.comment { xml.text(@comment) } unless @comment.blank?
        xml.installer {
          xml.text(Base64.encode64(@installer.read))
          xml.filename { xml.text(@installer.original_filename) }
          xml.signature { xml.text(Base64.encode64(@installer_signature.read)) } unless @installer_signature.blank?
        }
      }
    }
    begin
      # Rails.logger.info "\n\n req.doc=#{req.doc.to_xml.to_yaml}\n\n"
      resp = user.openvas_connection.sendrecv(req.doc)
      unless Agent.extract_value_from("//@status", resp) =~ /20\d/
        msg = Agent.extract_value_from("//@status_text", resp)
        errors[:command_failure] << msg
        return nil
      end
      @id = Agent.extract_value_from("/create_agent_response/@id", resp)
      true
    rescue Exception => e
      errors[:command_failure] << e.message
      nil
    end
  end

  def delete_record(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_agent(:agent_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = Agent.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Agent.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

  def verify_agent(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.verify_agent(:agent_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = Agent.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Agent.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end