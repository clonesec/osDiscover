require 'socket' 
require 'timeout'
require 'openssl'
require 'nokogiri'

module Openvas

	class OMPError < :: RuntimeError
		attr_accessor :req, :reason
		def initialize(req, reason = '')
			self.req = req
			self.reason = reason
		end
		def to_s
			"OpenVAS: #{self.reason}"
		end
	end

	class TimeoutError < OMPError
		def initialize
			self.reason = "Error: connection timeout"
		end
	end

	class OMPResponseError < OMPError
		def initialize
			self.reason = "Error in request/response"
		end
	end

	class OMPAuthError < OMPError
		def initialize
			self.reason = "Authentication failed"
		end
	end

	class XMLParsingError < OMPError
		def initialize
			self.reason = "XML parsing failed"
		end
	end

  class Connection

    def initialize(p={})
      @socket_check = nil
      @read_timeout = 10 # seconds
      @bufsize = 16384
      @areq = ''
      if p.has_key?("host")
        @host = p["host"]
      else
        return nil
      end
      if p.has_key?("port")
        @port = p["port"]
      else
        return nil
      end
      if p.has_key?("user")
        @user = p["user"]
      else
        return nil
      end
      if p.has_key?("password")
        @password = p["password"]
      else
        return nil
      end
      @bufsize = p["bufsize"] if p.has_key?("bufsize")
      @read_timeout = p["read_timeout"] if p.has_key?("read_timeout")
      connect # returns true or false
    end

    def socket_check
      @socket_check || nil
    end

  	def connect
  	  # note this will connect to any listening IP+port(socket), so we need to ensure that it's an openvas omp/oap server
  		begin
        timeout(10) { @plain_socket = TCPSocket.open(@host, @port) }
        ssl_context = OpenSSL::SSL::SSLContext.new()
        @socket = OpenSSL::SSL::SSLSocket.new(@plain_socket, ssl_context)
        @socket.sync_close = true
        @socket.connect
        @socket_check = true
        # Rails.logger.info "\n\n>>>>>> @socket.state=#{@socket.state.inspect}\nstate is sslok=#{@socket.state =~ /sslok/i}\n\n"
        # Rails.logger.info "\n\n>>>>>> @socket.state is sslok\n\n" if @socket.state =~ /sslok/i
      rescue Exception => ex
        Rails.logger.info "Exception in: Openvas::Connection#connect ... #{ex.inspect}\nhost=#{@host} | port=#{@port}"
        @socket_check = nil
        return false
  	  end
  	  true
  	end

  	def disconnect
  	  begin
    		@socket.close if @socket
      rescue
      end
  	end

  	def sendrecv(tosend)
  		connect unless @socket
  		@socket.puts(tosend)
  		@rbuf = ''
  		size = 0
  		begin
  			begin
  				timeout(@read_timeout) {
    		    a = @socket.sysread(@bufsize)
    		    size = a.length
    		    @rbuf << a
  				}
        rescue Exception => ex
          size = 0
          msg = ex.inspect
          msg.gsub!('#<', '')
          msg.gsub!('>', '')
          Rails.logger.info "Exception in: Openvas::Connection#sendrecv ... #{msg} ... host=#{@host} | port=#{@port}"
          # note this is a custom response coz sometimes openvas fails (e.g. invalid file uploads):
          return Nokogiri::XML("<exception_in_openvasconnection_sendrecv_response status=\"999\" status_text=\"" + msg + "\"/>")
  			end
  		end while size >= @bufsize
  		response = @rbuf
  		return Nokogiri::XML(response)
  	end

    # Helper method to extract a value from a Nokogiri::XML::Node object.  If the
    # xpath provided contains an @, then the method assumes that the value resides
    # in an attribute, otherwise it pulls the text of the last +text+ node.
    def extract_value_from(x_str, n)
      ret = ""
      return ret if x_str.nil? || x_str.empty?
      if x_str =~ /@/
        ret = n.at_xpath(x_str).value  if n.at_xpath(x_str)
      else
        tn =  n.at_xpath(x_str)
        if tn
          if tn.children.count > 0
            tn.children.each { |tnc|
              if tnc.text?
                ret = tnc.text
              end
            }
          else
            ret = tn.text
          end
        end
      end
      ret
    end

  	def login 
      areq = Nokogiri::XML::Builder.new { |xml|
        xml.authenticate {
          xml.credentials {
            xml.username { xml.text(@user) }
            xml.password { xml.text(@password) }
          }
        }
      }
      resp = sendrecv(areq.doc)
      # Rails.logger.info "\n\n resp=#{resp.to_xml.to_yaml}\n\n"
      if resp.nil?
        disconnect()
        return false
      end
      begin
        if extract_value_from("//@status", resp) =~ /20\d/
          @areq = areq
        elsif extract_value_from("//@status", resp) =~ /40\d/
          disconnect()
          return false
        else
          puts "\n\n***OMPAuthError*** OpenVAS response=#{resp.inspect}\n\n"
          raise OMPAuthError
        end
      rescue
        puts "\n\n***XMLParsingError*** OpenVAS response=#{resp.inspect}\n\n"
        raise XMLParsingError
      end
  	end

  	def logged_in?
  		if @areq == '' || @areq.nil?
  			return false
  		else
  			return true
  		end
  	end

  	def logout
  		disconnect()
  		@areq = ''
  	end

    def version
      # for OAP the first command has to be authenticate, but this is not true for OMP ... why?
      # for OAP the following is returned, which does not match the docs:
      # <get_version_response status="200" status_text="OK">
      #   <version preferred="yes">1.0</version>
      # </get_version_response>
      req = Nokogiri::XML::Builder.new { |xml| xml.get_version }
      # Rails.logger.info "\n req=#{req.to_xml.to_yaml}\n"
      resp = sendrecv(req.doc)
      # Rails.logger.info "resp=#{resp.to_xml.to_yaml}\n\n"
      ret = extract_value_from("/get_version_response/version", resp)
      ret
    end

  end

end