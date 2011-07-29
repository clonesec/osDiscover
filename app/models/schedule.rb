class Schedule

  include OpenvasModel

  attr_accessor :name, :comment, :first_time
  attr_accessor :period_amount, :period_unit, :duration_amount, :duration_unit, :next_time
  attr_accessor :next_time, :in_use, :task_ids, :period, :duration

  validates :name, :presence => true, :length => { :maximum => 80 }
  validates :comment, :length => { :maximum => 400 }
  validates :first_time, :presence => true

  def self.selections(user)
    schedules = []
    sch = Schedule.new({:id=>'0', :name=>'--'}) # add blank selection, so users can edit schedule selection
    schedules << sch
    self.all(user).each do |s|
      schedules << s
    end
    schedules
  end

  def self.all(user, options = {})
    manual_sort = false
    params = {:details => '1'}
    params[:schedule_id] = options[:id] if options[:id]
    case options[:sort_by]
      when :schedule_id
        params[:sort_field] = 'id'
      when :next_time
        manual_sort = true
      when :first_time
        params[:sort_field] = 'first_time'
      else
        params[:sort_field] = 'name'
    end
    req = Nokogiri::XML::Builder.new { |xml| xml.get_schedules(params) }
    ret = []
    begin
      schedules = user.openvas_connection.sendrecv(req.doc)
      schedules.xpath("//schedule").each { |s|
        sch               = Schedule.new
        sch.id            = extract_value_from("@id", s)
        sch.name          = extract_value_from("name", s)
        sch.comment       = extract_value_from("comment", s)
        t_time            = extract_value_from("first_time", s)
        sch.first_time    = Time.parse(t_time) unless t_time == ""
        t_time            = extract_value_from("next_time", s)
        if t_time == "" or t_time == "done" or t_time == "over"
          sch.next_time = t_time
        else
          sch.next_time = Time.parse(t_time)
        end
        sch.period = extract_value_from("period", s)
        sch.duration = extract_value_from("duration", s)
        # period_num = extract_value_from("period", s).to_i
        # if period_num > 0
        #   sch.period = VasPeriod.from_seconds(period_num)
        # end
        # period_num = extract_value_from("period_months", s).to_i
        # if period_num > 0
        #   sch.period = VasPeriod.from_months(period_num)
        # end
        # t_time            = extract_value_from("duration", s)
        # unless t_time == ""
        #   sch.duration = t_time.to_i unless t_time == 0
        # end
        sch.in_use = extract_value_from("in_use", s).to_i
        sch.task_ids = []
        # s.xpath('tasks/task/@id') { |t|
        #   sch.task_ids << t.value
        # }
        ret << sch
      }
      if manual_sort
        if options[:sort_by] == :next_time
          ret.sort!{ |a,b| a.next_time <=> b.next_time }
        end
      end
    rescue Exception => e
      raise e
    end
    ret
  end

  def save(user)
    # note modify(edit/update) is not implemented in OMP 2.0
    if valid?
      sch = Schedule.new
      sch.name            = self.name
      sch.comment         = self.comment
      sch.first_time      = self.first_time
      sch.period_amount   = self.period_amount
      sch.period_unit     = self.period_unit
      sch.duration_amount = self.duration_amount
      sch.duration_unit   = self.duration_unit
      sch.create_or_update(user)
      sch.errors.each do |attribute, msg|
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
      xml.create_schedule {
        xml.name    { xml.text(@name) }
        xml.comment { xml.text(@comment) } unless @comment.blank?
        xml.first_time {
          xml.minute       { xml.text(@first_time.min) }
          xml.hour         { xml.text(@first_time.hour) }
          xml.day_of_month { xml.text(@first_time.day) }
          xml.month        { xml.text(@first_time.month) }
          xml.year         { xml.text(@first_time.year) }
        }
        xml.duration {
          xml.text(@duration_amount ? @duration_amount : 0)
          xml.unit { xml.text(@duration_unit.to_s) }
        }
        xml.period {
          if @period_amount.blank?
            xml.text(0)
            xml.unit { xml.text("hour") }
          else
            xml.text(@period_amount ? @period_amount : 0)
            xml.unit { xml.text(@period_unit.to_s) }
          end
        }
      }
    }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      unless Schedule.extract_value_from("//@status", resp) =~ /20\d/
        msg = Schedule.extract_value_from("//@status_text", resp)
        errors[:command_failure] << msg
        return nil
      end
      @id = Schedule.extract_value_from("/create_schedule_response/@id", resp)
      true
    rescue Exception => e
      errors[:command_failure] << e.message
      nil
    end
  end

  def delete_record(user)
    return if @id.blank?
    req = Nokogiri::XML::Builder.new { |xml| xml.delete_schedule(:schedule_id => @id) }
    begin
      resp = user.openvas_connection.sendrecv(req.doc)
      status = Schedule.extract_value_from("//@status", resp)
      unless status =~ /20\d/
        msg = 'Error: (status ' + status + ') ' + Schedule.extract_value_from("//@status_text", resp)
        return msg
      end
      return ''
    rescue Exception => e
      return e.message
    end
  end

end