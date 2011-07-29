class PreferenceSelect

  attr_accessor :id, :name

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end unless attributes.nil?
  end

end