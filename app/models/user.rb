class User < ActiveRecord::Base

  devise :database_authenticatable, :trackable, :timeoutable

  attr_accessible :username, :email, :password, :password_confirmation

  def openvas_connection=(conn)
    @openvas_connection ||= conn
  end

  def openvas_connection
    @openvas_connection
  end

  def openvas_admin=(admin=false)
    @openvas_admin ||= admin
  end

  def openvas_admin?
    @openvas_admin
  end
    
  def show_reports(date)
	reports = []
	all_reports = Report.all(self)
	all_reports.each do |report|
		if Date.parse(report.ended_at.strftime('%Y/%m/%d')) == date
			reports << report
		end
	end
	return reports
  end
  
    def show_schedules(date)
	tasks = []
	all_tasks = Task.all(self)
		all_tasks.each do |task|
			if Date.parse(task.last_report_date) == date
				tasks << task
			end
		end
	return tasks
  end
  
  
  
############ Find Unique Scanned Hosts #############
  def unique_scanned_hosts
    hosts = []
    scanned_hosts = self.show_scanned_hosts
    scanned_hosts.each do |sh|
      sh.hosts.split(", ").each do |host|
        if host.scan("0/24").empty?
          hosts << host.gsub(/\s+/, "")
        else
          host = host.gsub(/\s+/, "").gsub("0/24", "")
          (0..255).each do |last_digit|
            tmp_host = "#{host}#{last_digit}"  
            hosts << tmp_host
          end
        end
      end
    end
    return hosts.uniq.sort
  end

  def scan_targets
    tmp_targets = []
    unique_tasks_ids = self.unique_tasks
    unique_tasks_ids.each do |task|
      tmp_targets << ScanTarget.find(task.target_id, self) if task.status == "Done"
    end
    return tmp_targets
  end
  
  def unique_tasks
    all_tasks = Task.all(self)
    unique_tasks_ids = Hash[all_tasks.map{|x| [x]}].keys
    return unique_tasks_ids
  end
  
  def unique_target_ids
    tmp_targets = self.scan_targets
    unique_target_ids = Hash[tmp_targets.map{|x| [x.id]}].keys
    return unique_target_ids
  end
  
  def show_scanned_hosts
    tmp_targets = []
    hosts = []
    unique_target_ids = self.unique_target_ids
    unique_target_ids.each do |target|
      tmp_target = ScanTarget.find(target, self)
      if tmp_target.name != "Localhost" #&& tmp_target == 
        hosts << tmp_target
      end
    end
    return hosts  
  end
  
  def unique_ips
    tmp_targets = []
    unique_ip_count = 0
    unique_target_ids = self.unique_target_ids
    unique_target_ids.each do |target|
      tmp_target = ScanTarget.find(target, self)
      if tmp_target.name != "Localhost" #&& tmp_target == 
        unique_ip_count = unique_ip_count + tmp_target.max_hosts.to_i
      end
    end
    return unique_ip_count  
  end
############ Find Unique Scanned Hosts #############



############ Find Unique Scanned Hosts with vulnerabilities #############
  def vulnerable_unique_hosts
    hosts = []
    scanned_hosts = self.severity_count
    scanned_hosts.each do |host|
        hosts << host.gsub(/\s+/, "")
    end
    return hosts.uniq.sort
  end

  def report_tasks
    tmp_tasks = []
    unique_reports = self.unique_reports
    unique_reports.each do |report|
      if report && report.hosts_threat_totals.sum > 0 && (report.active_threat == "High" || report.active_threat == "Medium")
        tmp_tasks << report #Task.find(self, id: report.task_id)  
      end
    end
    return tmp_tasks
  end
  
  def severity_count
    tmp_tasks = []
    tmp_targets = []
    total_vulnerable_hosts = []
    #all_reports = Report.all(self)
    tmp_tasks = self.report_tasks
    
      tmp_tasks.each do |t|     
       t.hosts.each do |h|
          total_vulnerable_hosts << h.host
        end
      end
    # unique_tmp_tasks = Hash[tmp_tasks.map{|x| [x.target_id] rescue nil} ].keys 
    # unique_tmp_tasks.each do |task|
      # tmp_targets << ScanTarget.find(task, self)
    # end
#     
    # @test = []
    # unique_target_ids = Hash[tmp_targets.map{|x| [x.id] rescue nil}].keys
    # unique_target_ids.each do |target|
      # tmp_target = ScanTarget.find(target, self)
      # if tmp_target.name != "Localhost"
        # total_vulnerable_hosts << tmp_target
      # end
    #end
    
    return total_vulnerable_hosts
  end
  
  def unique_reports
      unique_reports = Hash[self.all_latest_reports.map{|x| [x]}].keys
  end

  def all_latest_reports
    all_tasks = Task.all(self)
    tmp = []
    all_tasks.each do |task|
      tmp << Report.find({report_id: task.last_report_id}, self)
    end
    tmp
  end
############ Find Unique Scanned Hosts with vulnerabilities #############  


  def outdated_hosts
    hosts = []
    scanned_hosts = self.date_severity_count
    scanned_hosts.each do |sh|
      sh.hosts.split(", ").each do |host|
        hosts << host.gsub(/\s+/, "")
      end
    end
    return hosts.uniq.sort
  end
  
  def date_severity_count
    hosts = []
    tmp_targets = []
    all_tasks = Task.all(self)
    unique_tasks_ids = Hash[all_tasks.map{|x| [x]}].keys
    unique_tasks_ids.each do |task|
      unless task.last_report_date.empty?
        if Date.parse(task.last_report_date) + 90.days < Date.today
          tmp_targets << ScanTarget.find(task.target_id, self)
        end
      end
    end
    @test = []
    unique_target_ids = Hash[tmp_targets.map{|x| [x.id] rescue nil}].keys
    unique_target_ids.each do |target|
      tmp_target = ScanTarget.find(target, self)
      if tmp_target.name != "Localhost"
        hosts << tmp_target
      end
    end
    return hosts
  end
  
  
def unique_ips_results
  unique_ip_count = 0
  tmp_targets = []
  valid_targets = []
  all_tasks = Task.all(self)
  unique_tasks_ids = Hash[all_tasks.map{|x| [x]}].keys
  unique_tasks_ids.each do |task|
    tmp_targets << ScanTarget.find(task.target_id, self)
  end
  
  unique_target_ids = Hash[tmp_targets.map{|x| [x.id]}].keys
  unique_target_ids.each do |target|
    tmp_target = ScanTarget.find(target, self)
    if tmp_target.name != "Localhost"
      valid_targets << tmp_target
    end
  end
  return valid_targets
  end
  
def severity_count_results
  tmp_tasks = []
  tmp_targets = []
  valid_targets = []
  total_vulnerable_hosts = 0
  all_reports = Report.all(self)
  unique_reports = Hash[all_reports.map{|x| [x]}].keys
  unique_reports.each do |report|
    if report.hosts_threat_totals.sum > 0
      tmp_tasks << Task.find(self, id: report.task_id)  
    end
  end 
  unique_tmp_tasks = Hash[tmp_tasks.map{|x| [x.target_id]}].keys
  unique_tmp_tasks.each do |task|
    tmp_targets << ScanTarget.find(task, self)
  end 
  @test = []
  unique_target_ids = Hash[tmp_targets.map{|x| [x.id]}].keys
  unique_target_ids.each do |target|
    tmp_target = ScanTarget.find(target, self)
    if tmp_target.name != "Localhost"
      valid_targets << tmp_target
    end
  end 
  return valid_targets
  end
  
  def date_severity_count_results
    hosts = 0
  tmp_targets = []
  valid_targets = []
  all_tasks = Task.all(self)
  unique_tasks_ids = Hash[all_tasks.map{|x| [x]}].keys
  unique_tasks_ids.each do |task|
    if  Date.parse(task.last_report_date) + 90.days < Date.today
      tmp_targets << ScanTarget.find(task.target_id, self)
    end
  end
  @test = []
  unique_target_ids = Hash[tmp_targets.map{|x| [x.id]}].keys
  unique_target_ids.each do |target|
    tmp_target = ScanTarget.find(target, self)
    if tmp_target.name != "Localhost"
      valid_targets << tmp_target
    end
  end
  return valid_targets
  end
 
end






