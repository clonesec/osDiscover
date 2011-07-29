class Family

  include OpenvasModel

  attr_accessor :name, :nvt_count, :max_nvt_count, :growing

  validates :name, :presence => true, :length => { :maximum => 80 }

end