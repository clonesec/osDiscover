require 'base64'

module OpenvasModel

  extend  ActiveSupport::Concern
  # previously a module looked like this:
  #   module M
  #     def self.included(base)
  #       base.send(:extend, ClassMethods)
  #       base.send(:include, InstanceMethods)
  #       scope :foo, :conditions => { :created_at => nil }
  #     end
  #     module ClassMethods
  #       def cm; puts 'I am a class method'; end
  #     end
  #     module InstanceMethods
  #       def im; puts 'I am an instance method'; end
  #     end
  #   end
  # by using ActiveSupport::Concern it can now look like this:
  #   module M
  #     extend ActiveSupport::Concern
  #     included do
  #       scope :foo, :conditions => { :created_at => nil }
  #     end
  #     module ClassMethods
  #       def cm; puts 'I am a class method'; end
  #     end
  #     module InstanceMethods
  #       def im; puts 'I am an instance method'; end
  #     end
  #   end

  include ActiveModel::Validations
  include ActiveModel::Dirty
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :id, :persisted

  module InstanceMethods
    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end unless attributes.nil?
    end

    def persisted?
      # note: since we are not using ActiveRecord for persistence, but ActiveModel instead, 
      #       we need to manually manipulate the return value for "persisted?" so that 
      #       "form_for" in the views will set the correct route and post/put action 
      #       ... i.e. set to false for new/create actions, and true for edit/update actions:
      @persisted || false
    end

    def new_record?
      @id == nil || @id.empty?
    end

    def destroy
      delete_record(nil)
    end

    def delete_record(user)
      false
    end

    def save(user)
      false
    end

    def create_or_update(user)
      false
    end

    def update_attributes(attrs={})
      # attrs.each { |key, value|
      #   send("#{key}=".to_sym, value) if public_methods.include?("#{key}=".to_sym)
      # }
      # save
      false
    end
  end # module InstanceMethods

  module ClassMethods

    # note: the following is from lib/active_record/attribute_methods/time_zone_conversion.rb:
    # time = _read_attribute('#{attr_name}')
    # @attributes_cache['#{attr_name}'] = time.acts_like?(:time) ? time.in_time_zone : time

    def find(id, user)
      return nil if id.blank? || user.blank?
      f = self.all(user, :id=>id).first
      return nil if f.blank?
      # ensure "first" has the desired id:
      if f.id.to_s == id.to_s
        return f
      else
        return nil
      end
    end

    def all(user, options = {})
      []
    end

    def selections(user)
      return nil if user.nil?
      objs = []
      objs = self.all(user)
    end

    def status_can_delete(status)
      if ['New','Done'].include? status
        return true
      elsif ['Stopped'].include? status
        return true
      elsif ['Paused'].include? status
        return false
      elsif ['Running'].include? status
        return false
      elsif ['Internal Error'].include? status
        # note these may not be delete-able, but openvas will return an error (or not) so it doesn't matter.
        return true
      else # one of many 'requested' statuses
        return false
      end
      false
    end

    # helper class method to extract a value from a Nokogiri::XML::Node object.
    # If the xpath provided contains an @, then the method assumes that the value 
    # resides in an attribute, otherwise it pulls the text of the last +text+ node.
    def extract_value_from(x_str, n)
      ret = ""
      return ret if x_str.nil? || x_str.empty?
      if x_str =~ /@/
        ret = n.at_xpath(x_str).value if n.at_xpath(x_str)
      else
        tn = n.at_xpath(x_str)
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
  end # module ClassMethods

end