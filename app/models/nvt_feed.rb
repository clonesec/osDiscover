class NvtFeed

  include OpenvasModel

  attr_accessor :name, :version, :description

  def self.describe_feed(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.describe_feed }
    resp = user.openvas_connection.sendrecv(req.doc)
    ret = []
    resp.xpath('//describe_feed_response/feed').each { |s|
      vs = NvtFeed.new
      vs.name         = extract_value_from("name", s)
      vs.version      = extract_value_from("version", s)
      vs.description  = extract_value_from("description", s)
      ret << vs
    }
    ret
  end

  def self.sync_feed(user)
    req = Nokogiri::XML::Builder.new { |xml| xml.sync_feed }
    user.openvas_connection.sendrecv(req.doc)
  end

end