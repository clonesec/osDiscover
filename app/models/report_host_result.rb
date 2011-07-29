class ReportHostResult

  attr_accessor :host, :started_at, :ended_at
  attr_accessor :high, :medium, :low, :log, :debug, :false_positive

  def incr_high=(value)
    @high += value.to_i
  end

  def incr_medium=(value)
    @medium += value.to_i
  end

  def incr_low=(value)
    @low += value.to_i
  end

  def incr_log=(value)
    @log += value.to_i
  end

  def incr_debug=(value)
    @debug += value.to_i
  end

  def incr_false_positive=(value)
    @false_positive += value.to_i
  end

  def total
    # FIXME if views are showing debug counts uncomment this:
    # high + medium + low + log + debug + false_positive
    high + medium + low + log + false_positive
  end

end