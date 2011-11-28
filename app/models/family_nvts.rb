class FamilyNvts

  include OpenvasModel

  attr_accessor :nvts
  attr_accessor :nvts_in_family_count, :nvts_in_family
  attr_accessor :nvts_in_family_and_config_count, :nvts_in_family_and_config

  def set_nvts
    # i.e. no Nvt's are selected in family for this config:
    @nvts = @nvts_in_family and return if @nvts_in_family_and_config.blank?
    # if @nvts_in_family_and_config.blank?
    #   @nvts = @nvts_in_family
    #   Rails.logger.info "none selected: @nvts.count=#{@nvts.count}"
    #   return
    # end

    # i.e. all Nvt's selected in family for this config:
    @nvts = @nvts_in_family_and_config and return if @nvts_in_family_count == @nvts_in_family_and_config_count
    # if @nvts_in_family_count == @nvts_in_family_and_config_count
    #   @nvts = @nvts_in_family_and_config
    #   Rails.logger.info "all selected: @nvts.count=#{@nvts.count}"
    #   return
    # end

    @nvts = [] if @nvts.blank?
    # thestart = Time.now
    unless @nvts_in_family_count == @nvts_in_family_and_config_count || @nvts_in_family_and_config.blank?
      name_and_oid = @nvts_in_family_and_config.map {|n| "#{Nvt.extract_value_from("@oid", n)}#{Nvt.extract_value_from("name", n)}"}
      # Rails.logger.info "name_and_oid=#{name_and_oid.inspect}"
      @nvts_in_family.each_with_index do |nvt, x|
        y = name_and_oid.index("#{Nvt.extract_value_from("@oid", nvt)}#{Nvt.extract_value_from("name", nvt)}")
        # Rails.logger.info "y=#{y.inspect} | name_and_oid=#{name_and_oid[y] unless y.nil?}"
        n = y.nil? ? nvt : @nvts_in_family_and_config[y]
        @nvts << n
      end
    end
    # Rails.logger.info ">>> after: create @nvts loop ... elapsed: #{Time.now - thestart} sec.s\n\n"
  end

  def self.get_family_nvts(user, config_id, family)
    fn = FamilyNvts.new
    # thestart = Time.now
    # get the details for all NVT's in the family:
    only_family = {family:family, preference_count:1, sort_order:'ascending', sort_field:'nvts.name'}
    # note this should never be nil, even if absolutely no NVT's are selected, as there are always families:
    fn.nvts_in_family = Nvt.find_by_family(user, only_family)
    fn.nvts_in_family_count = fn.nvts_in_family.nil? ? 0 : fn.nvts_in_family.count
    # Rails.logger.info ">>> Nvt.find_by_family ... elapsed: #{Time.now - thestart} sec.s"

    # thestart = Time.now
    # get the details for all NVT's in the config in the family:
    config_id_and_family = {config_id:config_id, family:family, timeout:1, preference_count:1, selected:true, sort_order:'ascending', sort_field:'nvts.name'}
    # note this may be nil if no NVT's are selected:
    fn.nvts_in_family_and_config = Nvt.find_by_config_id_and_family(user, config_id_and_family)
    fn.nvts_in_family_and_config_count = fn.nvts_in_family_and_config.nil? ? 0 : fn.nvts_in_family_and_config.count
    # Rails.logger.info ">>> Nvt.find_by_config_id_and_family ... elapsed: #{Time.now - thestart} sec.s\n\n"
    fn.set_nvts
    fn
  end

end