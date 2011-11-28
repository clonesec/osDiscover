class Preference

  include OpenvasModel

  attr_accessor :name, :value, :nvt_id, :nvt_name, :val_type_desc
  attr_accessor :config_id, :val_type, :timeout
  attr_accessor :preference_values

  def preference_values
    @preference_values ||= []
  end

end