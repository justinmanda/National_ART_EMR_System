# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def link_to_onmousedown(name, options = {}, html_options = nil, *parameters_for_method_reference)
    html_options = Hash.new if html_options.nil?
    html_options["onMouseDown"]="this.style.backgroundColor='lightblue';document.location=this.href"
    html_options["onClick"]="return false" #if we don't do this we get double clicks
    link = link_to(name, options, html_options, *parameters_for_method_reference)
  end

  def img_button_submit_to(url, image, options = {}, params = {})
    content = ""
    content << "<form method='post' action='#{url}'><input type='image' src='#{image}'/>"
    params.each {|n,v| content << "<input type='hidden' name='#{n}' value='#{v}'/>" }
    content << "</form>"
    content
  end
  
  def img_button_submit_to_with_confirm(url, image, options = {}, params = {})
    content = ""
    content << "<form " + ((options[:form_id])?("id=#{options[:form_id]}"):"id='frm_general'") + " method='post' action='#{url}'><input type='image' src='#{image}' " +
      ((options[:confirm])?("onclick=\"return confirmRecordDeletion('" +
      options[:confirm] + "', '" + ((options[:form_id])?("#{options[:form_id]}"):"frm_general") + "')\""):"") + "/>"

    params.each {|n,v| content << "<input type='hidden' name='#{n}' value='#{v}'/>" }
    content << "</form>"
    content
  end
  
  def fancy_or_high_contrast_touch
    fancy = get_global_property_value("interface") == "fancy" rescue false
    fancy ? "touch-fancy.css" : "touch.css"
  end
  
  def show_intro_text
    get_global_property_value("show_intro_text").to_s == "true" rescue false
  end
  
  def ask_home_village
    get_global_property_value("demographics.home_village").to_s == "true" rescue false
  end

  def site_prefix
    site_prefix = get_global_property_value("site_prefix") rescue false
    return site_prefix
  end

  def ask_mothers_surname
    get_global_property_value("demographics.mothers_surname").to_s == "true" rescue false
  end
  
  def ask_middle_name
    get_global_property_value("demographics.middle_name").to_s == "true" rescue false
  end

  def ask_visit_home_for_TB_therapy
    get_global_property_value("demographics.visit_home_for_treatment").to_s == "true" rescue false
  end
  
  def ask_sms_for_TB_therapy
    get_global_property_value("demographics.sms_for_TB_therapy").to_s == "true" rescue false
  end

  def ask_ground_phone
    get_global_property_value("demographics.ground_phone").to_s == "true" rescue false
  end

  def ask_blood_pressure
    get_global_property_value("vitals.blood_pressure").to_s == "true" rescue false
  end

  def ask_temperature
    get_global_property_value("vitals.temperature").to_s == "true" rescue false
  end  

  def ask_standard_art_side_effects
    get_global_property_value("art_visit.standard_art_side_effects").to_s == "true" rescue false
  end  

  def show_lab_results
    get_global_property_value('show.lab.results').to_s == "true" rescue false
  end
  
  def use_filing_number
    get_global_property_value('use.filing.number').to_s == "true" rescue false
  end

  def use_user_selected_activities
    get_global_property_value('use.user.selected.activities').to_s == "true" rescue false
  end

  def use_extended_staging_questions
    get_global_property_value('use.extended.staging.questions').to_s == "true" rescue false
  end
  
  def prefix
    get_global_property_value("dc.number.prefix") rescue ""
  end

	def advanced_prescription_interface
		get_global_property_value("advanced.prescription.interface").to_s == "true" rescue false
	end

	def get_global_property_value(global_property)
		property_value = Settings[global_property] 
		if property_value.nil?
			property_value = GlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
													).property_value rescue nil
		end
		return property_value
	end

  def month_name_options(selected_months = [])
    i=0
    options_array = [[]] +Date::ABBR_MONTHNAMES[1..-1].collect{|month|[month,i+=1]} + [["Unknown","Unknown"]]
    options_for_select(options_array, selected_months)  
  end
  
  def age_limit
    Time.now.year - 1890
  end

  def version
    #"Bart Version: #{BART_VERSION}#{' ' + BART_SETTINGS['installation'] if BART_SETTINGS}, #{File.ctime(File.join(RAILS_ROOT, 'config', 'environment.rb')).strftime('%d-%b-%Y')}"
    style = "style='background-color:red;'" unless session[:datetime].blank?
    "Bart Version: #{BART_VERSION} - <span #{style}>#{(session[:datetime].to_date rescue Date.today).strftime('%A, %d-%b-%Y')}</span>"
  end
  
  def welcome_message
    "Muli bwanji, enter your user information or scan your id card. <span style='font-size:0.6em;float:right'>(#{version})</span>"  
  end
  
  def show_identifiers(location_id, patient)
    content = ""
    idents = get_global_property_value("dashboard.identifiers")
    json = JSON.parse(idents)
    names = json[location_id.to_s] rescue []
    names.each do |name|
      ident_type = PatientIdentifierType.find_by_name(name)
      next if ident_type.blank?
      ident = patient.patient_identifiers.find_by_identifier_type(ident_type.id)
      next if ident.blank?
      content << "<span class='title'>#{name}:</span> #{ident.identifier}"       
    end
    content
  end
  
  def patient_image(patient) 
    @patient.person.gender == 'M' ? "<img src='/images/male.gif' alt='Male' height='30px' style='margin-bottom:-4px;'>" : "<img src='/images/female.gif' alt='Female' height='30px' style='margin-bottom:-4px;'>"
  end

  # include (patient, :names => true) to list registered guardians
  def relationship_options(patient, options={})
    options_array = []
    if options[:names] # show names of guardians as options
      rels = patient.relationships.all
      # filter out voided relationship target
      rels.each do |rel|
        unless rel.relation.blank?
          options_array << [rel.relation.name + " (#{rel.type.b_is_to_a})",
                            rel.relation.name]
        end
      end
      options_array << ['None', 'None']
    else
      options_array << ['Yes', 'Yes']
      options_array << ['No', 'No']
    end
    options_array << ['Unknown', 'Unknown']
    options_for_select(options_array)  
  end
  
  def program_enrollment_options(patient, filter_program_name=nil)
    progs = @patient.patient_programs.all
    progs.reject!{|prog| prog.program.name != filter_program_name} unless filter_program_name.blank?
    options_array = progs.map{|prog| [prog.program.name + " (started #{prog.date_enrolled.strftime('%d/%b/%Y')} at #{prog.location.name})", prog.id]}
    options_for_select(options_array)  
  end
  
  def concept_set_options(concept_name)
    concept_id = concept_id = ConceptName.find_by_name(concept_name).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }
    options_for_select(options)
  end

	def concept_set_options_unknown(concept_name)
		concept_id = concept_id = ConceptName.find_by_name(concept_name).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] } - [["Unknown", "Unknown"]]
    options_for_select(options)
	end

  def selected_concept_set_options(concept_name, exclude_concept_name)
    concept_id = concept_id = ConceptName.find_by_name(concept_name).concept_id
    
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    exclude_concept_id = ConceptName.find_by_name(exclude_concept_name).concept_id
    
    exclude_set = ConceptSet.find_all_by_concept_set(exclude_concept_id, :order => 'sort_weight')
    exclude_options = exclude_set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    options_for_select(options - exclude_options)
  end
  
  def concept_set(concept_name)
    concept_id = ConceptName.find_by_name(concept_name).concept_id
    
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname] }
    return options
  end

  def development_environment?
    ENV['RAILS_ENV'] == 'development'
  end

  def generic_locations
    field_name = "name"

    Location.find_by_sql("SELECT *
            FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location'))
             ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
  end
  
  def concept_sets(concept_name)
	concept_id = ConceptName.find_by_name(concept_name).concept_id

    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    set.map{|item|next if item.concept.blank? ; item.concept.fullname }
  end

  def convert_time(duration)
		if(!duration.blank?)
			if(duration.to_i < 7)
				(duration.to_i > 0)?(( duration.to_i > 1)? "#{duration} days" :"1 day"): "<i>(New)</i>"
			elsif(duration.to_i < 30)
				week = (duration.to_i)/7
				week > 1? "#{week} weeks" : "1 week"
			elsif(duration.to_i < 367)
				month = (duration.to_i)/30
				month > 1? "#{month} months" : "1 month"
			else
				year = (duration.to_i)/365
				year > 1? "#{year} years" : "1 year"
			end
		end
	end

  def preferred_user_keyboard
    UserProperty.find(:first,
      :conditions =>["property = ? AND user_id = ?",'preferred.keyboard', 
      current_user.id]).property_value rescue 'abc'
  end

  def create_from_dde_server                                                    
    CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false
  end 

  def current_user_roles                                                        
    user_roles = UserRole.find(:all,:conditions =>["user_id = ?", current_user.id]).collect{|r|r.role}
    RoleRole.find(:all,:conditions => ["child_role IN (?)", user_roles]).collect{|r|user_roles << r.parent_role}
    return user_roles.uniq
    
  end

  def suggested_return_date(patient,dispensed_date)
    session_date = dispensed_date.to_date
    drugs_given = Hash.new()
    PatientService.drugs_given_on(patient, session_date).uniq.each do |order|
      drug = order.drug_order.drug
      next unless MedicationService.arv(drug)
      if drugs_given[drug.name].blank? 
        drugs_given[drug.name] = {:quantity => order.drug_order.quantity ,
                               :dose => order.drug_order.equivalent_daily_dose,
                               :auto_expire_date => order.auto_expire_date 
                              }
      else
        drugs_given[drug.name] = {:quantity => order.drug_order.quantity + drugs_given[drug.name][:quantity],
                               :dose => order.drug_order.equivalent_daily_dose,
                               :auto_expire_date => order.auto_expire_date 
                              }
      end
    end rescue {}

    return if drugs_given.blank?

    min_pills_given_per_drug = 0
    auto_expire_date = nil
    return_date = nil 
    (drugs_given || {}).each do |name,values|
      if ((values[:quantity] <= min_pills_given_per_drug) || min_pills_given_per_drug == 0)
        min_pills_given_per_drug = values[:quantity] 
        return_date = dispensed_date + (values[:quantity]/values[:dose]).days
        auto_expire_date = values[:auto_expire_date].to_date rescue dispensed_date
      end
    end
   
    #here we check if the prescription period is is inline with what was dispensed
    #if not we go with the date when the actual drugs will run out
    if auto_expire_date <= return_date
      return_date = auto_expire_date
    end unless auto_expire_date.blank?

    #if the suggested_return_date is available we add a two day buffer by subtracting
    #two days to the suggested_return_date
    return_date -= 2.day if return_date 
    return return_date
  end

  def current_program_location                                                  
    current_user_activities = current_user.activities                      
    if Location.current_location.name.downcase == 'outpatient'                  
      return "OPD"                                                              
    elsif current_user_activities.include?('Manage Lab Orders') or current_user_activities.include?('Manage Lab Results') or
       current_user_activities.include?('Manage Sputum Submissions') or current_user_activities.include?('Manage TB Clinic Visits') or
       current_user_activities.include?('Manage TB Reception Visits') or current_user_activities.include?('Manage TB Registration Visits') or
       current_user_activities.include?('Manage HIV Status Visits')             
       return 'TB program'                                                      
    else #if current_user_activities                                            
       return 'HIV program'                                                     
    end                                                                         
  end

  def what_app?                                                                 
    if current_user.activities.include?('Manage Lab Orders') or current_user.activities.include?('Manage Lab Results') or
       current_user.activities.include?('Manage Sputum Submissions') or current_user.activities.include?('Manage TB Clinic Visits') or
       current_user.activities.include?('Manage TB Reception Visits') or current_user.activities.include?('Manage TB Registration Visits') or
       current_user.activities.include?('Manage HIV Status Visits')             
      'TB-ART'                                                                  
    else                                                                        
      'BART'                                                                    
    end                                                                         
  end 

  def require_viral_load_check(patient)

		arv_start_date = PatientService.patient_art_start_date(patient).to_date rescue nil
    second_line_art_start_date = PatientService.date_started_second_line_regimen(patient).to_date rescue nil
    return false if arv_start_date.blank?
    duration = PatientService.period_on_treatment(arv_start_date).to_i rescue 0
    unless (second_line_art_start_date.blank? || second_line_art_start_date == "")
      duration = PatientService.period_on_treatment(second_line_art_start_date).to_i rescue 0
    end
    if (second_line_art_start_date.blank? || second_line_art_start_date == "")
      if (duration >= 6)
        obs = Observation.find(:all, :conditions => ["person_id = ? and concept_id = ?",
            patient.patient_id, Concept.find_by_name("Viral load").concept_id])
        return true if obs == []
        if !(obs.empty?)
          viral_loads = obs.map(&:obs_datetime)
          if (viral_loads.length == 1)
            viral_load_date = viral_loads.first.to_date
            duration = PatientService.period_on_treatment(viral_load_date).to_i
            if (duration/24 >= 1)
              return true
            else
              return false
            end
          end

          if (viral_loads.length > 1)
            viral_load_date = viral_loads.last.to_date
            duration = PatientService.period_on_treatment(viral_load_date).to_i
            if (duration/24 >= 1)
              return true
            else
              return false
            end
          end
        end
      end
    else
      if (duration >= 6)
        second_line_art_start_date = second_line_art_start_date.to_date
        obs = Observation.find(:all, :conditions => ["person_id = ? and concept_id = ?",
            patient.patient_id, Concept.find_by_name("Viral load").concept_id])
        return true if obs == []
        if !(obs.empty?)
          viral_loads = obs.map(&:obs_datetime)
          viral_loads = viral_loads.collect{|viral_load|viral_load.to_date}
          viral_loads.delete_if{|viral_load|viral_load < second_line_art_start_date}
          return true if viral_loads == []
          if (viral_loads != [])
            viral_load_date = viral_loads.last
            duration = PatientService.period_on_treatment(viral_load_date)
            if (duration/24 >= 1)
              return true
            else
              return false
            end
          end
        end
      end
    end
	end


  def new_viral_load_check(patient)

		arv_start_date = PatientService.patient_art_start_date(patient).to_date rescue nil
    return false if arv_start_date.blank?
    period_on_art_in_months = PatientService.period_on_treatment(arv_start_date).to_i rescue 0
    second_line_art_start_date = PatientService.date_started_second_line_regimen(patient).to_date rescue nil
    return false unless second_line_art_start_date.blank?
    today = Date.today

    milestones = {
                  6 => (6..7), 24 => (24..26), 48 => (48..50),
                  72 => (72..74), 96 => (96..98), 120 => (120..122),
                  144 => (144..146), 168 => (168..170), 192 => (192..194),
                  216 => (216..218), 240 => (240..242), 260 => (260..262)
                 }

    viral_loads = Observation.find(:all, :conditions => ["person_id = ? and concept_id = ?",
            patient.patient_id, Concept.find_by_name("Viral load").concept_id])

    latest_viral_load = viral_loads.last.obs_datetime.to_date rescue nil

    @identifier_types = ["Legacy Pediatric id","National id","Legacy National id"]
		identifier_types = PatientIdentifierType.find(:all,:conditions=>["name IN (?)",@identifier_types]).collect{| type |type.id }

		patient_identifiers = PatientIdentifier.find(:all, :conditions=>["patient_id=? AND identifier_type IN (?)",
        patient.id,identifier_types]).collect{| i | i.identifier }
		
    results = Lab.latest_result_by_test_type(patient, 'HIV_viral_load', patient_identifiers) rescue nil
    latest_viral_results_date = results[0].sub("::HIV_RNA_PCR",'').to_date rescue nil
    return false if latest_viral_results_date.blank?
    
      milestones.each do |key, value|

        if (period_on_art_in_months >= key)
          range = value.to_a
          grace_period = range.last - range.first
          mile_stone_date = arv_start_date + key.months
          mile_stone_grace_period = mile_stone_date + grace_period.months

          if (today >= mile_stone_date && today <=  mile_stone_grace_period)

            if (latest_viral_results_date >= mile_stone_date && latest_viral_results_date <= mile_stone_grace_period)
               if latest_viral_load.blank?
                 return true
               end
               if (latest_viral_load >= mile_stone_date && latest_viral_load <= mile_stone_grace_period)
                 return false
               else
                 return true
               end
            else
              return false
            end
          else
            return false
          end

        else
          return false
        end

      end
   
	end
  
  def modified_viral_load_check(patient)

		arv_start_date = PatientService.patient_art_start_date(patient).to_date rescue nil
    return false if arv_start_date.blank?
    period_on_art_in_months = PatientService.period_on_treatment(arv_start_date).to_i rescue 0
    return false if (period_on_art_in_months < 6)
    second_line_art_start_date = PatientService.date_started_second_line_regimen(patient).to_date rescue nil
    return false unless second_line_art_start_date.blank?
    today = Date.today

    milestones = {
                  6 => [6,8], 24 => [24,27], 48 => [48,51],
                  72 => [72,75], 96 => [96,99], 120 => [120,123],
                  144 => [144,147], 168 => [168,171], 192 => [192,195],
                  216 => [216,219], 240 => [240,243], 260 => [260,263]
                 }

    identifier_types = ["Legacy Pediatric id","National id","Legacy National id"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",identifier_types]).collect{| type |type.id }
                                                                                
    patient_identifiers = PatientIdentifier.find(:all, 
      :conditions=>["patient_id=? AND identifier_type IN (?)",
      patient.id,identifier_types]).collect{| i | i.identifier }              
                                                                                
    results = Lab.latest_result_by_test_type(patient, 'HIV_viral_load', patient_identifiers) rescue nil
    latest_viral_results_date = results[0].split('::')[0].to_date rescue nil

    milestone_exceeded = true
      milestones.each do |key, value|
          grace_period = value.last - value.first
          mile_stone_date = arv_start_date + key.months
          mile_stone_grace_period = mile_stone_date + grace_period.months
         if (period_on_art_in_months >= key && period_on_art_in_months <= value.last)
           milestone_exceeded = false
          if (today >= mile_stone_date && today <=  mile_stone_grace_period)
            return true if latest_viral_results_date.blank?
             if (latest_viral_results_date >= mile_stone_date && latest_viral_results_date <= mile_stone_grace_period)
               return false
             else
               return true
             end
          else
            return false
          end
        end
      end
      return false if milestone_exceeded
	end

  def improved_viral_load_check(patient)

    arv_start_date = PatientService.patient_art_start_date(patient).to_date rescue nil
    return false if arv_start_date.blank?
    period_on_art_in_months = PatientService.period_on_treatment(arv_start_date).to_i rescue 0
    return false if (period_on_art_in_months < 6)
    second_line_art_start_date = PatientService.date_started_second_line_regimen(patient).to_date rescue nil
    return false unless second_line_art_start_date.blank?
    today = Date.today

    milestones = {
                  6 => [6,8], 24 => [24,27], 48 => [48,51],
                  72 => [72,75], 96 => [96,99], 120 => [120,123],
                  144 => [144,147], 168 => [168,171], 192 => [192,195],
                  216 => [216,219], 240 => [240,243], 260 => [260,263]
                 }

    identifier_types = ["Legacy Pediatric id","National id","Legacy National id"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",identifier_types]).collect{| type |type.id }

    patient_identifiers = PatientIdentifier.find(:all,
      :conditions=>["patient_id=? AND identifier_type IN (?)",
      patient.id,identifier_types]).collect{| i | i.identifier }

    results = Lab.latest_result_by_test_type(patient, 'HIV_viral_load', patient_identifiers) rescue nil
    latest_viral_results_date = results[0].split('::')[0].to_date rescue nil

    milestone_exceeded = true

    milestones.each do |key, value|
          grace_period = value.last - value.first
          mile_stone_date = arv_start_date + key.months
          mile_stone_grace_period = mile_stone_date + grace_period.months
          
          if (viral_load_popup_activated(arv_start_date, patient, period_on_art_in_months) && latest_viral_results_date.blank?)
            milestone_exceeded = false
            return true
          end

          unless latest_viral_results_date.blank?
            valid_min_date = today - 6.months
            return false if (latest_viral_results_date >= valid_min_date && latest_viral_results_date <= today)

            if (viral_load_popup_activated(arv_start_date, patient, period_on_art_in_months))
              if !(latest_viral_results_date >= valid_min_date && latest_viral_results_date <= today)
                milestone_exceeded = false
                return true
              end
            end
          end

          if (period_on_art_in_months >= key && period_on_art_in_months <= value.last)
           milestone_exceeded = false
            if (today >= mile_stone_date && today <=  mile_stone_grace_period)
              return true if latest_viral_results_date.blank?
               if (latest_viral_results_date >= valid_min_date && latest_viral_results_date <= today)
                 return false
               else
                 return true
               end
            else
              return false
            end
          end
    end
      return false if milestone_exceeded
	end

  def viral_load_popup_activated(art_start_date, patient, period_on_art)
    possible_ranges = [
                       [6,23],[24,47],[48,71],[72,95],[96,119],[120,143],
                       [144,167],[168,191],[192,215],[216,239],[240,259],
                       [260,283]
                      ]

    possible_ranges.each do |key,value|
      if (period_on_art >= key && period_on_art <= value)
        first_date = art_start_date + key.months
        second_date = art_start_date + value.months
        viral_loads_request = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? 
            AND DATE(obs_datetime) >= ? AND DATE(obs_datetime) <= ?",
            patient.patient_id, Concept.find_by_name("Viral load").concept_id, first_date, second_date])
        return true unless viral_loads_request.blank?
        if (viral_loads_request.blank?)
          viral_loads_request = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?",
            patient.patient_id, Concept.find_by_name("Viral load").concept_id])
          return true unless viral_loads_request.blank?
          return false if viral_loads_request.blank?
        end
      end
    end

  end
end
