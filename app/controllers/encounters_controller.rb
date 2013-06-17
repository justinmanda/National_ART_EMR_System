class EncountersController < GenericEncountersController
	def new
		#raise params.to_yaml
		@patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id])
		@patient_bean = PatientService.get_patient(@patient.person)
		session_date = session[:datetime].to_date rescue Date.today

		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
			@todays_date = session_date
			logger.info('========================== Suggesting appointment date =================================== @ '  + Time.now.to_s)
			@suggested_appointment_date = suggest_appointment_date
			logger.info('========================== Completed suggesting appointment date =================================== @ '  + Time.now.to_s)
      render :action => params[:encounter_type] and return
		end


			@hiv_status = tb_art_patient(@patient,"hiv program") rescue ""
			@tb_status = tb_art_patient(@patient,"TB program") rescue ""
			@show_tb_types = false
			consultation_tb_status = Patient.find_by_sql("
											SELECT patient_id, current_state_for_program(patient_id, 2, '#{session_date}') AS state, c.name as status
											FROM patient p INNER JOIN program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(patient_id, 2, '#{session_date}')
											INNER JOIN concept_name c ON c.concept_id = pw.concept_id where p.patient_id = '#{@patient.patient_id}'").first.status rescue ""
			 if consultation_tb_status == "Currently in treatment"
				 @consultation_tb_status = "Confirmed TB on treatment"
			 elsif consultation_tb_status == "Symptomatic but NOT in treatment" or @hiv_status.to_s.upcase == "POSITIVE"
				 @consultation_tb_status = "Confirmed TB NOT on treatment"
			 else
				 @show_tb_types = true
				 @consultation_tb_status = "Unknown"
			 end
		@current_hiv_program_status = Patient.find_by_sql("
											SELECT patient_id, current_state_for_program(patient_id, 1, '#{session_date}') AS state, c.name as status
											FROM patient p INNER JOIN program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(patient_id, 1, '#{session_date}')
											INNER JOIN concept_name c ON c.concept_id = pw.concept_id where p.patient_id = '#{@patient.patient_id}'").first.status rescue "Unknown"
	
		if (params[:from_anc] == 'true')
      bart_activities = ['Manage Vitals','Manage HIV clinic consultations',
        'Manage ART adherence','Manage HIV staging visits','Manage HIV first visits',
        'Manage HIV reception visits','Manage drug dispensations','Manage prescription']

      current_user_activities = []
      current_user.activities.each{|a| current_user_activities << a.upcase }

      user_property = UserProperty.find(:first,
        :conditions =>["property = 'Activities' AND user_id = ?",current_user.id])

      (bart_activities).each do |activity|
        if not current_user_activities.include?(activity.upcase)
          user_property.property_value += ",#{activity}" rescue "" unless current_user.activities.blank?
          user_property.property_value = activity if current_user.activities.blank?
          user_property.save 
        end
      end
    end


		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end
		@current_height = PatientService.get_patient_attribute_value(@patient, "current_height", session_date)

		@min_weight = PatientService.get_patient_attribute_value(@patient, "min_weight")
    @max_weight = PatientService.get_patient_attribute_value(@patient, "max_weight")
    @min_height = PatientService.get_patient_attribute_value(@patient, "min_height")
    @max_height = PatientService.get_patient_attribute_value(@patient, "max_height")
    @given_arvs_before = given_arvs_before(@patient)
    @current_encounters = @patient.encounters.find_by_date(session_date)
    @previous_tb_visit = previous_tb_visit(@patient.id)
    @is_patient_pregnant_value = nil
    @is_patient_breast_feeding_value = nil
    @currently_using_family_planning_methods = nil
    @transfer_in_TB_registration_number = get_todays_observation_answer_for_encounter(@patient.id, "TB_INITIAL", "TB registration number")
    @referred_to_htc = nil
    @family_planning_methods = []

    if 'tb_reception'.upcase == (params[:encounter_type].upcase rescue '')
      @phone_numbers = PatientService.phone_numbers(Person.find(params[:patient_id]))
    end
       
    if 'HIV_CLINIC_CONSULTATION' == (params[:encounter_type].upcase rescue '') || 'ART_ADHERENCE' == (params[:encounter_type].upcase rescue '')
      session_date = session[:datetime].to_date rescue Date.today

      @allergic_to_sulphur = Observation.find(Observation.find(:first,
          :order => "obs_datetime DESC,date_created DESC",
          :conditions => ["person_id = ? AND concept_id = ?
                            AND DATE(obs_datetime) = ?",@patient.id,
            ConceptName.find_by_name("Allergic to sulphur").concept_id,session_date])).to_s.strip.squish rescue ''

      @obs_ans = Observation.find(Observation.find(:first,
          :order => "obs_datetime DESC,date_created DESC",
          :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",
            @patient.id,ConceptName.find_by_name("Prescribe drugs").concept_id,session_date])).to_s.strip.squish rescue ''
            
    end
        
    if (params[:encounter_type].upcase rescue '') == 'UPDATE HIV STATUS'
      @referred_to_htc = get_todays_observation_answer_for_encounter(@patient.id, "UPDATE HIV STATUS", "Refer to HTC")
    end

		@given_lab_results = Encounter.find(:last,
			:order => "encounter_datetime DESC,date_created DESC",
			:conditions =>["encounter_type = ? and patient_id = ?",
				EncounterType.find_by_name("GIVE LAB RESULTS").id,@patient.id]).observations.map{|o|
      o.answer_string if o.to_s.include?("Laboratory results given to patient")} rescue nil

		@transfer_to = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("TB VISIT").id,@patient.id]).observations.map{|o|
      o.answer_string if o.to_s.include?("Transfer out to")} rescue nil

		@recent_sputum_results = PatientService.recent_sputum_results(@patient.id) rescue nil

    @recent_sputum_submissions = PatientService.recent_sputum_submissions(@patient.id)

		@continue_treatment_at_site = []
		Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ? AND DATE(encounter_datetime) = ?",
        EncounterType.find_by_name("TB CLINIC VISIT").id,
        @patient.id,session_date.to_date]).observations.map{|o| @continue_treatment_at_site << o.answer_string if o.to_s.include?("Continue treatment")} rescue nil

		@patient_has_closed_TB_program_at_current_location = PatientProgram.find(:all,:conditions =>
        ["voided = 0 AND patient_id = ? AND location_id = ? AND (program_id = ? OR program_id = ?)", @patient.id, Location.current_health_center.id, Program.find_by_name('TB PROGRAM').id, Program.find_by_name('MDR-TB PROGRAM').id]).last.closed? rescue true

		if (params[:encounter_type].upcase rescue '') == 'IPT CONTACT PERSON'
			@contacts_ipt = []
						
			@ipt_contacts_ = @patient.tb_contacts.collect{|person| person unless PatientService.get_patient(person).age > 6}.compact rescue []
			@ipt_contacts.each do | person |
				@contacts_ipt << PatientService.get_patient(person)
			end
		end
		
		@select_options = select_options
		@months_since_last_hiv_test = PatientService.months_since_last_hiv_test(@patient.id)
		@current_user_role = self.current_user_role
		@tb_patient = is_tb_patient(@patient)
		@art_patient = PatientService.art_patient?(@patient)
		@recent_lab_results = patient_recent_lab_results(@patient.id)
		
		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
			@todays_date = session_date
			logger.info('========================== Suggesting appointment date =================================== @ '  + Time.now.to_s)
			@suggested_appointment_date = suggest_appointment_date
			logger.info('========================== Completed suggesting appointment date =================================== @ '  + Time.now.to_s)
		end
    
		@drug_given_before = PatientService.drug_given_before(@patient, session[:datetime])


		@hiv_status = PatientService.patient_hiv_status(@patient)
		@hiv_test_date = PatientService.hiv_test_date(@patient.id)
    
		@lab_activities = lab_activities
		# @tb_classification = [["Pulmonary TB","PULMONARY TB"],["Extra Pulmonary TB","EXTRA PULMONARY TB"]]
		@tb_patient_category = [["New","NEW"], ["Relapse","RELAPSE"], ["Retreatment after default","RETREATMENT AFTER DEFAULT"], ["Fail","FAIL"], ["Other","OTHER"]]
		@sputum_visual_appearance = [['Muco-purulent','MUCO-PURULENT'],['Blood-stained','BLOOD-STAINED'],['Saliva','SALIVA']]

		@sputum_results = [['Negative', 'NEGATIVE'], ['Scanty', 'SCANTY'], ['1+', 'Weakly positive'], ['2+', 'Moderately positive'], ['3+', 'Strongly positive']]

		@sputum_orders = Hash.new()
		@sputum_submission_waiting_results = Hash.new()
		@sputum_results_not_given = Hash.new()
		@art_first_visit = is_first_hiv_clinic_consultation(@patient.id)
		@tb_first_registration = is_first_tb_registration(@patient.id)
		@tb_programs_state = uncompleted_tb_programs_status(@patient)
		@had_tb_treatment_before = ever_received_tb_treatment(@patient.id)
		@any_previous_tb_programs = any_previous_tb_programs(@patient.id)

		PatientService.sputum_orders_without_submission(@patient.id).each { | order | 
			@sputum_orders[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text
		}
		
		sputum_submissons_with_no_results(@patient.id).each{|order| @sputum_submission_waiting_results[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text}
		sputum_results_not_given(@patient.id).each{|order| @sputum_results_not_given[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text}

		@tb_status = recent_lab_results(@patient.id, session_date)
    # use @patient_tb_status  for the tb_status moved from the patient model
    @patient_tb_status = PatientService.patient_tb_status(@patient)
		@patient_is_transfer_in = is_transfer_in(@patient)
		@patient_transfer_in_date = get_transfer_in_date(@patient)
		@patient_is_child_bearing_female = is_child_bearing_female(@patient)
    @cell_number = @patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue ''

    @tb_symptoms = []

		if (params[:encounter_type].upcase rescue '') == 'TB_INITIAL'
			current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight", session_date)
			tb_program = Program.find_by_name('TB Program')
			@tb_regimen_array = MedicationService.regimen_options(current_weight, tb_program)
			tb_program = Program.find_by_name('MDR-TB Program')
			@tb_regimen_array += MedicationService.regimen_options(current_weight, tb_program)
			@tb_regimen_array += [['Other', 'Other'], ['Unknown', 'Unknown']]
		end

		if (params[:encounter_type].upcase rescue '') == 'TB_VISIT'
		  @current_encounters.reverse.each do |enc|
        enc.observations.each do |o|
          @tb_symptoms << o.answer_string.strip if o.to_s.include?("TB symptoms") rescue nil
        end
      end
		end

		@location_transferred_to = []
		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
		  @old_appointment = nil
		  @report_url = nil
		  @report_url =  params[:report_url]  and @old_appointment = params[:old_appointment] if !params[:report_url].nil?
		  @current_encounters.reverse.each do |enc|
        enc.observations.each do |o|
          @location_transferred_to << o.to_s_location_name.strip if o.to_s.include?("Transfer out to") rescue nil
        end
      end
		end

		@tb_classification = nil
		@eptb_classification = nil
		@tb_type = nil

		@patients = nil
		
		if (params[:encounter_type].upcase rescue '') == "SOURCE_OF_REFERRAL"
			people = PatientService.person_search(params)
			@patients = []
			people.each do | person |
				patient = PatientService.get_patient(person)
				@patients << patient
			end
		end

		if (params[:encounter_type].upcase rescue '') == 'TB_REGISTRATION'

			tb_clinic_visit_obs = Encounter.find(:first,:order => "encounter_datetime DESC",
				:conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
          session_date, @patient.id, EncounterType.find_by_name('TB CLINIC VISIT').id]).observations rescue []

			(tb_clinic_visit_obs || []).each do | obs | 
				if obs.concept_id == Concept.find_by_name('EPTB classification').concept_id
					#@tb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname if Concept.find_by_name('TB classification').concept_id
					@eptb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname #if obs.concept_id == Concept.find_by_name('EPTB classification').concept_id
					#@tb_type = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname if obs.concept_id == Concept.find_by_name('TB type').concept_id
 				end
				if  obs.concept_id == Concept.find_by_name('TB classification').concept_id
					 @tb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name
				end
				if obs.concept_id == Concept.find_by_name('TB type').concept_id
					@tb_type = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name
				end
			end

		end

    if  ['HIV_CLINIC_CONSULTATION', 'TB_VISIT', 'HIV_STAGING'].include?((params[:encounter_type].upcase rescue ''))
			@local_tb_dot_sites_tag = tb_dot_sites_tag 
			for encounter in @current_encounters.reverse do
				if encounter.name.humanize.include?('Hiv staging') || encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation') 
					encounter = Encounter.find(encounter.id, :include => [:observations])
					for obs in encounter.observations do
						if obs.concept_id == ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
							@is_patient_pregnant_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end

						if obs.concept_id == ConceptName.find_by_name("IS PATIENT BREAST FEEDING?").concept_id
							@is_patient_breast_feeding_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end
					end

					if encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation')
						encounter = Encounter.find(encounter.id, :include => [:observations])
						for obs in encounter.observations do
							if obs.concept_id == ConceptName.find_by_name("CURRENTLY USING FAMILY PLANNING METHOD").concept_id
								@currently_using_family_planning_methods = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
							end

							if obs.concept_id == ConceptName.find_by_name("FAMILY PLANNING METHOD").concept_id
								@family_planning_methods << "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
							end
						end
					end
				end
			end
    end

		if CoreService.get_global_property_value('use.normal.staging.questions').to_s == "true"
			@who_stage_peds_i = concept_set('WHO STAGE I PEDS')
			@who_stage_peds_ii = concept_set('WHO STAGE II PEDS')
			@who_stage_peds_iii = concept_set('WHO STAGE III PEDS')
			@who_stage_peds_iv = concept_set('WHO STAGE IV PEDS')

			@who_stage_adults_i = concept_set('WHO STAGE I ADULT')
			@who_stage_adults_ii = concept_set('WHO STAGE II ADULT')
			@who_stage_adults_iii = concept_set('WHO STAGE III ADULT')
			@who_stage_adults_iv = concept_set('WHO STAGE IV ADULT')
		end

		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' or (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_REGISTRATION'
			if @patient_bean.age > 14 
				@who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I ADULT')
				@who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II ADULT')
				@who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III ADULT')
				@who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV ADULT')

				if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
					@not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked adult')
				end
			else
				@who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I PEDS')
				@who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II PEDS')
				@who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III PEDS')
				@who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV PEDS')
				if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
					@not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked peds')
				end
			end

			if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING'
				#added current weight to use on HIV staging for infants
				@current_weight = PatientService.get_patient_attribute_value(@patient,
          "current_weight")
				if !@retrospective
					@who_stage_i = @who_stage_i - concept_set('Unspecified Staging Conditions')
					@who_stage_ii = @who_stage_ii - concept_set('Unspecified Staging Conditions')
					@who_stage_iii = @who_stage_iii - concept_set('Unspecified Staging Conditions')
					@who_stage_iv = @who_stage_iv - concept_set('Unspecified Staging Conditions') - concept_set('Calculated WHO HIV staging conditions')
				end

				@moderate_wasting = []
				@severe_wasting = []
				if @patient_bean.age < 15
					median_weight_height = WeightHeightForAge.median_weight_height(@patient_bean.age_in_months, @patient.person.gender) rescue []
					current_weight_percentile = (@current_weight/(median_weight_height[0])*100)

					if current_weight_percentile >= 70 && current_weight_percentile <= 79
						@moderate_wasting = ["Moderate unexplained wasting/malnutrition not responding to treatment (weight-for-height/ -age 70-79% or muac 11-12 cm)"]
						@who_stage_iii = @who_stage_iii.flatten.uniq if CoreService.get_global_property_value('use.extended.staging.questions').to_s != "true"       
						@severe_wasting = []
					elsif current_weight_percentile < 70
						@severe_wasting = ["Severe unexplained wasting or malnutrition not responding to treatment (weight-for-height/ -age <70% or MUAC less than 11cm or oedema)"]
						@who_stage_iv = @who_stage_iv.flatten.uniq if CoreService.get_global_property_value('use.extended.staging.questions').to_s != "true"
						@moderate_wasting = []
					end
				end
				
				reason_for_art = @patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue []
        @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
				if !@reason_for_art_eligibility.nil? && @reason_for_art_eligibility.upcase == 'NONE'
					@reason_for_art_eligibility = nil				
				end
			end
			
			if @tb_status == true && @hiv_status != 'Negative'
        tb_hiv_exclusions = [['Pulmonary tuberculosis (current)', 'Pulmonary tuberculosis (current)'],
					['Tuberculosis (PTB or EPTB) within the last 2 years', 'Tuberculosis (PTB or EPTB) within the last 2 years']]
				#@who_stage_iii = @who_stage_iii - tb_hiv_exclusions
			end

  			
			@confirmatory_hiv_test_type = @patient.person.observations.question("CONFIRMATORY HIV TEST TYPE").last.answer_concept_name.name rescue 'UNKNOWN'
		end

		@avilable_status = ''
		@avilable_status = PatientService.patient_tb_status(@patient).upcase if PatientService.patient_tb_status(@patient).upcase == ('CONFIRMED TB NOT ON TREATMENT' || 'CONFIRMED TB ON TREATMENT')

		@arv_drugs = nil

		if (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_REGISTRATION'
			other = []

=begin
			use_regimen_short_names = CoreService.get_global_property_value("use_regimen_short_names") rescue "false"
			show_other_regimen = ("show_other_regimen") rescue 'false'

			@answer_array = arv_regimen_answers(:patient => @patient,
				:use_short_names    => use_regimen_short_names == "true",
				:show_other_regimen => show_other_regimen      == "true")

			hiv_program = Program.find_by_name('HIV Program')
			current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight")
			@answer_array = MedicationService.regimen_options(current_weight, hiv_program)
			@answer_array += [['Other', 'Other'], ['Unknown', 'Unknown']]
=end
			

			@arv_drugs = MedicationService.arv_drugs.collect { | drug | 
				if (CoreService.get_global_property_value('use_regimen_short_names').to_s == "true" rescue false)					
					other << [drug.concept.shortname, drug.concept.shortname] if (drug.concept.shortname.upcase.include?('OTHER') || drug.concept.shortname.upcase.include?('UNKNOWN'))
					[drug.concept.shortname, drug.concept.shortname] 
				else
					other << [drug.concept.fullname, drug.concept.fullname] if (drug.concept.fullname.upcase.include?('OTHER') || drug.concept.fullname.upcase.include?('UKNOWN'))
					[drug.concept.fullname, drug.concept.fullname]
				end
			}
			@arv_drugs = @arv_drugs - other
			@arv_drugs = @arv_drugs.sort {|a,b| a.to_s.downcase <=> b.to_s.downcase}
			@arv_drugs = @arv_drugs + other

			@require_hiv_clinic_registration = require_hiv_clinic_registration
		end

		if PatientIdentifier.site_prefix == "MPC"
				prefix = "LL-TB"
		else
				prefix = "#{PatientIdentifier.site_prefix}-TB"
		end
		@tb_auto_number = create_tb_number(PatientIdentifierType.find_by_name('District TB Number').id, prefix)

		if params["staging_conditions"] == "YES"
			@obs = params["observations"]
			render :template => 'encounters/normal_staging_summary', :layout => "normal_staging" and return
		end
		
		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient) and return unless params[:encounter_type]

		redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
		
		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' and  (CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true" rescue false)
			render :template => 'encounters/extended_hiv_staging'
		#elsif (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' and  (CoreService.get_global_property_value('use.normal.staging.questions').to_s == "true" rescue false)
		#	render :template => 'encounters/normal_hiv_staging'
		else
			render :action => params[:encounter_type] if params[:encounter_type]
		end
		
	end

	def check_tb_number
						value = params[:value]
            if PatientIdentifier.site_prefix == "MPC"
							tb_identifier = value.to_i
							value = "LL-TB  #{session[:datetime].to_date.strftime('%Y')} #{tb_identifier}" rescue  "LL-TB #{Date.today.strftime('%Y')} #{tb_identifier}"
						else
							tb_identifier = value.to_i
							value = "#{PatientIdentifier.site_prefix}-TB #{session[:datetime].to_date.strftime('%Y')} #{tb_identifier}" rescue  "#{PatientIdentifier.site_prefix}-TB #{Date.today.strftime('%Y')} #{tb_identifier}"
						end

						 render :text => ("false".to_json) if ! PatientIdentifier.find_by_identifier(value).blank?

						 render :text => ("true".to_json) if  PatientIdentifier.find_by_identifier(value).blank?
	end
	def tb_art_patient(patient,program)
    program_id = Program.find_by_name(program).id
    enrolled = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id]).blank?
 

		return true if enrolled
    false
  end

  def select_options
    select_options = {
      'reason_for_tb_clinic_visit' => [
        ['',''],
        ['Clinical review (Children, Smear-, HIV+)','CLINICAL REVIEW'],
        ['Smear Positive (HIV-)','SMEAR POSITIVE'],
        ['X-ray result interpretation','X-RAY RESULT INTERPRETATION']
      ],
			'tb_investigation' =>[
				['',''],
				['Sputum Test','TB sputum test'],
				['X-Ray','X-Ray'],
				['None','None']
			],
      'tb_clinic_visit_type' => [
        ['',''],
        ['Lab analysis','Lab follow-up'],
        ['Follow-up','Follow-up'],
        ['Clinical review (Clinician visit)','Clinical review']
      ],
      'family_planning_methods' => [
        ['',''],
        ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
        ['Depo-Provera', 'DEPO-PROVERA'],
        ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
        ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
        ['Male condoms', 'MALE CONDOMS'],
        ['Female condoms', 'FEMALE CONDOMS'],
        ['Rhythm method', 'RYTHM METHOD'],
        ['Withdrawal method', 'WITHDRAWAL METHOD'],
        ['Abstinence', 'ABSTINENCE'],
        ['Tubal ligation', 'TUBAL LIGATION'],
        ['Vasectomy', 'VASECTOMY']
      ],
      'male_family_planning_methods' => [
        ['',''],
        ['Male condoms', 'MALE CONDOMS'],
        ['Withdrawal method', 'WITHDRAWAL METHOD'],
        ['Rhythm method', 'RYTHM METHOD'],
        ['Abstinence', 'ABSTINENCE'],
        ['Vasectomy', 'VASECTOMY'],
        ['Other','OTHER']
      ],
      'female_family_planning_methods' => [
        ['',''],
        ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
        ['Depo-Provera', 'DEPO-PROVERA'],
        ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
        ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
        ['Female condoms', 'FEMALE CONDOMS'],
        ['Withdrawal method', 'WITHDRAWAL METHOD'],
        ['Rhythm method', 'RYTHM METHOD'],
        ['Abstinence', 'ABSTINENCE'],
        ['Tubal ligation', 'TUBAL LIGATION'],
        ['Emergency contraception', 'EMERGENCY CONTRACEPTION'],
        ['Other','OTHER']
      ],
      'drug_list' => [
        ['',''],
        ["Rifampicin Isoniazid Pyrazinamide and Ethambutol", "RHEZ (RIF, INH, Ethambutol and Pyrazinamide tab)"],
        ["Rifampicin Isoniazid and Ethambutol", "RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t"],
        ["Rifampicin and Isoniazid", "RH (Rifampin and Isoniazid tablet)"],
        ["Stavudine Lamivudine and Nevirapine", "D4T+3TC+NVP"],
        ["Stavudine Lamivudine + Stavudine Lamivudine and Nevirapine", "D4T+3TC/D4T+3TC+NVP"],
        ["Zidovudine Lamivudine and Nevirapine", "AZT+3TC+NVP"]
      ],
      'presc_time_period' => [
        ["",""],
        ["1 month", "30"],
        ["2 months", "60"],
        ["3 months", "90"],
        ["4 months", "120"],
        ["5 months", "150"],
        ["6 months", "180"],
        ["7 months", "210"],
        ["8 months", "240"]
      ],
      'continue_treatment' => [
        ["",""],
        ["Yes", "YES"],
        ["DHO DOT site","DHO DOT SITE"],
        ["Transfer Out", "TRANSFER OUT"]
      ],
      'hiv_status' => [
        ['',''],
        ['Negative','NEGATIVE'],
        ['Positive','POSITIVE'],
        ['Unknown','UNKNOWN']
      ],
      'who_stage1' => [
        ['',''],
        ['Asymptomatic','ASYMPTOMATIC'],
        ['Persistent generalised lymphadenopathy','PERSISTENT GENERALISED LYMPHADENOPATHY'],
        ['Unspecified stage 1 condition','UNSPECIFIED STAGE 1 CONDITION']
      ],
      'who_stage2' => [
        ['',''],
        ['Unspecified stage 2 condition','UNSPECIFIED STAGE 2 CONDITION'],
        ['Angular cheilitis','ANGULAR CHEILITIS'],
        ['Popular pruritic eruptions / Fungal nail infections','POPULAR PRURITIC ERUPTIONS / FUNGAL NAIL INFECTIONS']
      ],
      'who_stage3' => [
        ['',''],
        ['Oral candidiasis','ORAL CANDIDIASIS'],
        ['Oral hairly leukoplakia','ORAL HAIRLY LEUKOPLAKIA'],
        ['Pulmonary tuberculosis','PULMONARY TUBERCULOSIS'],
        ['Unspecified stage 3 condition','UNSPECIFIED STAGE 3 CONDITION']
      ],
      'who_stage4' => [
        ['',''],
        ['Toxaplasmosis of the brain','TOXAPLASMOSIS OF THE BRAIN'],
        ["Kaposi's Sarcoma","KAPOSI'S SARCOMA"],
        ['Unspecified stage 4 condition','UNSPECIFIED STAGE 4 CONDITION'],
        ['HIV encephalopathy','HIV ENCEPHALOPATHY']
      ],
      'tb_xray_interpretation' => [
        ['',''],
        ['Consistent of TB','Consistent of TB'],
        ['Not Consistent of TB','Not Consistent of TB']
      ],
      'lab_orders' =>{
        "Blood" => ["Full blood count", "Malaria parasite", "Group & cross match", "Urea & Electrolytes", "CD4 count", "Resistance",
          "Viral Load", "Cryptococcal Antigen", "Lactate", "Fasting blood sugar", "Random blood sugar", "Sugar profile",
          "Liver function test", "Hepatitis test", "Sickling test", "ESR", "Culture & sensitivity", "Widal test", "ELISA",
          "ASO titre", "Rheumatoid factor", "Cholesterol", "Triglycerides", "Calcium", "Creatinine", "VDRL", "Direct Coombs",
          "Indirect Coombs", "Blood Test NOS"],
        "CSF" => ["Full CSF analysis", "Indian ink", "Protein & sugar", "White cell count", "Culture & sensitivity"],
        "Urine" => ["Urine microscopy", "Urinanalysis", "Culture & sensitivity"],
        "Aspirate" => ["Full aspirate analysis"],
        "Stool" => ["Full stool analysis", "Culture & sensitivity"],
        "Sputum-AAFB" => ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)"],
        "Sputum-Culture" => ["Culture(1st)", "Culture(2nd)"],
        "Swab" => ["Microscopy", "Culture & sensitivity"]
      },
      'tb_symptoms_short' => [
        ['',''],
        ["Bloody cough", "Hemoptysis"],
        ["Chest pain", "Chest pain"],
        ["Cough", "Cough lasting more than three weeks"],
        ["Fatigue", "Fatigue"],
        ["Fever", "Relapsing fever"],
        ["Loss of appetite", "Loss of appetite"],
        ["Night sweats","Night sweats"],
        ["Shortness of breath", "Shortness of breath"],
        ["Weight loss", "Weight loss"],
        ["Other", "Other"]
      ],
      'tb_symptoms_all' => [
        ['',''],
        ["Bloody cough", "Hemoptysis"],
        ["Bronchial breathing", "Bronchial breathing"],
        ["Crackles", "Crackles"],
        ["Cough", "Cough lasting more than three weeks"],
        ["Failure to thrive", "Failure to thrive"],
        ["Fatigue", "Fatigue"],
        ["Fever", "Relapsing fever"],
        ["Loss of appetite", "Loss of appetite"],
       # ["Meningitis", "Meningitis"],
        ["Night sweats","Night sweats"],
        ["Peripheral neuropathy", "Peripheral neuropathy"],
        ["Shortness of breath", "Shortness of breath"],
        ["Weight loss", "Weight loss"],
        ["Other", "Other"]
      ],
      'drug_related_side_effects' => [
        ['',''],
        ["Confusion", "Confusion"],
        ["Deafness", "Deafness"],
        ["Dizziness", "Dizziness"],
        ["Peripheral neuropathy","Peripheral neuropathy"],
        ["Skin itching/purpura", "Skin itching"],
        ["Visual impairment", "Visual impairment"],
        ["Vomiting", "Vomiting"],
        ["Yellow eyes", "Jaundice"],
        ["Other", "Other"]
      ],
      'tb_patient_categories' => [
        ['',''],
        ["New", "New patient"],
        ["Failure", "Failed - TB"],
        ["Relapse", "Relapse MDR-TB patient"],
        ["Treatment after default", "Treatment after default MDR-TB patient"],
        ["Other", "Other"]
      ],
      'duration_of_current_cough' => [
        ['',''],
        ["Less than 1 week", "Less than one week"],
        ["1 Week", "1 week"],
        ["2 Weeks", "2 weeks"],
        ["3 Weeks", "3 weeks"],
        ["4 Weeks", "4 weeks"],
        ["More than 4 Weeks", "More than 4 weeks"],
        ["Unknown", "Unknown"]
      ],
      'eptb_classification'=> [
        ['',''],
        ['Pleural effusion', 'Pleural effusion'],
        ['Lymphadenopathy', 'Lymphadenopathy'],
        ['Pericardial effusion', 'Pericardial effusion'],
        ['Ascites', 'Ascites'],
        ['Spinal disease', 'Spinal disease'],
        ['Meningitis','Meningitis'],
        ['Other', 'Other']
      ],
      'tb_types' => [
        ['',''],
        ['Susceptible', 'Susceptible to tuberculosis drug'],
       # ['Multi-drug resistant (MDR)', 'Multi-drug resistant tuberculosis'],
        ['Extensive drug resistant (XDR)', 'Extensive drug resistant tuberculosis']
      ],
      'tb_classification' => [
        ['',''],
        ['Pulmonary tuberculosis (PTB)', 'Pulmonary tuberculosis'],
        ['Extrapulmonary tuberculosis (EPTB)', 'Extrapulmonary tuberculosis (EPTB)']
      ],
      'source_of_referral' => [
        ['',''],
        ['Walk in', 'Walk in'],
        ['Index Patient', 'Index Patient'],
        ['HTC', 'HTC clinic'],
        ['ART/PMTCT', 'ART Clinic/PMTCT'],
        ['OPD', 'OPD'],
        ['Private practitioner', 'Private practitioner'],
        ['Sputum collection point', 'Sputum collection point'],
        ['Other','Other']
      ]
    }
  end

	def is_holiday(suggest_date, holidays)
		holiday = false;
		holidays.each do |h|
			if (h.to_date.strftime('%B %d') == suggest_date.strftime('%B %d'))
				holiday = true;
			end
		end
		return holiday
	end

	def return_original_suggested_date(suggested_date, booked_dates)
		suggest_original_date = nil
		#second_biggest_date_available = nil

		booked_dates.each do |booked_date|
			sdate = booked_date.to_s.split(":")[0].to_date

			if(sdate.to_date >= suggested_date.to_date)
				#second_biggest_date_available = suggested_date
				suggest_original_date = sdate
				suggested_date = sdate
			end
		end if booked_dates.to_s.size > 0

		@massage="All available days this calender week are fully booked"

		return suggest_original_date
	end

	def is_below_limit(recommended_date, bookings)
		clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i rescue 0
		clinic_appointment_limit = 0 if clinic_appointment_limit.blank?
		within_limit = true
	
		if (bookings.blank? || clinic_appointment_limit <= 0)
			within_limit = true;
		else
			recommended_date_limit = bookings[recommended_date] rescue 0

			if (recommended_date_limit >= clinic_appointment_limit)
				within_limit = false
			end
		end

		return within_limit
	end

	def suggested_date(expiry_date, holidays, bookings, clinic_days)
    bookings.delete_if{|bd| holidays.collect{|h|h.to_date.to_s[5..-1]}.include?(bd.to_s[5..-1])}
    recommended_date = nil                                                      
    clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i rescue 0

    @encounter_type = EncounterType.find_by_name('APPOINTMENT')                  
    @concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id        
          
    number_of_bookings = {}
                                                                      
    (bookings || []).sort.reverse.each do |date|   
      next if not clinic_days.collect{|c|c.upcase}.include?(date.strftime('%A').upcase)
      limit = number_of_booked_patients(date.to_date).to_i rescue 0
      if limit < clinic_appointment_limit                                  
        recommended_date = date
        break 
      else
        number_of_bookings[date] = limit
      end
    end          
                                                                   
    (number_of_bookings || {}).sort_by { |dates,num| num }.each do |dates , num|   
      next if not clinic_days.collect{|c|c.upcase}.include?(dates.strftime('%A').upcase)
      recommended_date = dates                                                  
      break 
    end if recommended_date.blank?                                                                        

    recommended_date = expiry_date if recommended_date.blank?
    return recommended_date
	end

  def assign_close_to_expire_date(set_date,auto_expire_date)
    if (set_date < auto_expire_date)
      while (set_date < auto_expire_date)
        set_date = set_date + 1.day
      end
      #Give the patient a 2 day buffer*/
      set_date = set_date - 1.day
    end
    return set_date
  end

	def suggest_appointment_date
		#for now we disable this because we are already checking for this
		#in the browser - the method is suggested_return_date
		#@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)

		dispensed_date = session[:datetime].to_date rescue Date.today
		expiry_date = prescription_expiry_date(@patient, dispensed_date)
		
		#if the patient is a child (age 14 or less) and the peads clinic days are set - we
		#use the peads clinic days to set the next appointment date		
		peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days')
				
		if (@patient_bean.age <= 14 && !peads_clinic_days.blank?)
			clinic_days = peads_clinic_days
		else
			clinic_days = CoreService.get_global_property_value('clinic.days') || 'Monday,Tuesday,Wednesday,Thursday,Friday'		
		end
		clinic_days = clinic_days.split(',')		

		bookings = bookings_within_range(expiry_date)
    
		clinic_holidays = CoreService.get_global_property_value('clinic.holidays') 
		clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date}.join(',').split(',') rescue []
		
		return suggested_date(expiry_date ,clinic_holidays, bookings, clinic_days)
	end
	
	def prescription_expiry_date(patient, dispensed_date)
    session_date = dispensed_date.to_date
        
    arvs_given = false
		
    #get all drug dispensed on set clinic day
		drugs_given_on = PatientService.drugs_given_on(patient, session_date)

		orders_made = drugs_given_on.reject do |o|
      !MedicationService.tb_medication(o.drug_order.drug) 
    end

		auto_expire_date = Date.today + 2.days
		
		if orders_made.blank?
			orders_made = drugs_given_on
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date unless orders_made.blank?
      
      regimen_type_concept = nil
      (orders_made || []).each do |o|
        next unless MedicationService.arv(o.drug_order.drug)
        regimen_type_concept = ConceptName.find_by_name("ARV regimens received abstracted construct").concept_id 
        arvs_given = true
        break
      end
		else
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date
      regimen_type_concept = ConceptName.find_by_name("TB REGIMEN TYPE").concept_id
		end
		
		treatment_encounter = orders_made.first

		treatment_encounter = treatment_encounter.encounter.id rescue treatment_encounter.encounter_id
		#raise treatment_encounter.to_yaml
    arv_regimen_obs = Observation.find_by_sql("SELECT * FROM obs 
      WHERE concept_id = #{regimen_type_concept} 
      AND encounter_id = #{treatment_encounter} LIMIT 1") rescue []

		arv_regimen_type = "" 
		unless arv_regimen_obs.blank?
			arv_regimen_type = arv_regimen_obs.to_s
		end

		starter_pack = false
		if arv_regimen_type.match(/STARTER PACK/i)
			starter_pack = true
		end

    #==========================================================================================
    calculated_expire_date = auto_expire_date

    order = orders_made.sort_by(&:auto_expire_date).first 

    #............................................................................................ 
    amounts_brought_to_clinic = Observation.find_by_sql("SELECT * FROM obs      
      INNER JOIN drug_order USING (order_id)                                    
      WHERE obs.concept_id = #{ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id}
      AND drug_order.drug_inventory_id = #{order.drug_order.drug_inventory_id}  
      AND obs.obs_datetime >= '#{session_date.to_date}'                         
      AND obs.obs_datetime <= '#{session_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      AND person_id = #{patient.id}")                                           
                                                                                
    total_brought_to_clinic = amounts_brought_to_clinic.sum{|amount| amount.value_numeric}
                                                                                
    total_brought_to_clinic = total_brought_to_clinic + amounts_brought_to_clinic.sum{|amount| (amount.value_text.to_f rescue 0)}
                                                                                
    hanging_pills_duration = ((total_brought_to_clinic)/order.drug_order.equivalent_daily_dose).to_i
                                                                                
    expire_date = order.auto_expire_date + hanging_pills_duration.days        
                                                                                
    calculated_expire_date = expire_date.to_date if expire_date.to_date > calculated_expire_date

    #............................................................................................ 


    auto_expire_date = calculated_expire_date
		
		buffer = 0		
		if starter_pack
			buffer = 1
		else			
			buffer = 2
		end

		buffer = 0 if !arvs_given
		return auto_expire_date - buffer.days
	end
	
  def bookings_within_range(end_date = nil)
    clinic_days = GlobalProperty.find_by_property("clinic.days")
    clinic_days = clinic_days.property_value.split(',') rescue 'Monday,Tuesday,Wednesday,Thursday,Friday'.split(',')

    start_date = (end_date - 4.days)
    booked_dates = [end_date]
  
    (1.upto(4)).each do |num|
      booked_dates << (end_date - num.day)                               
    end
    
    clinic_holidays = CoreService.get_global_property_value('clinic.holidays')  
    clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date}.join(',').split(',') rescue []
    return_booked_dates = []
  
    unless clinic_holidays.blank?
      (booked_dates || []).each do |date|
        next if is_holiday(date,clinic_holidays)
        return_booked_dates << date
      end
    else
      return_booked_dates = booked_dates
    end

    return return_booked_dates
  end

  def create_remote
    location = Location.find(params["location"]) rescue nil
    user = User.first rescue nil

    if !location.nil? and !user.nil?
      self.current_location = location
      User.current = user

      Location.current_location = location

      target = {
        :observations=>[],
        :encounter=>params["encounter"]
      }

      params["obs"].each{|k,v|
        target[:observations] << v
      }

      params = target
      if params[:change_appointment_date] == "true"
        session_date = session[:datetime].to_date rescue Date.today
        type = EncounterType.find_by_name("APPOINTMENT")
        appointment_encounter = Observation.find(:first,
          :order => "encounter_datetime DESC,encounter.date_created DESC",
          :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
          :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
      AND encounter_datetime >= ? AND encounter_datetime <= ?",
            ConceptName.find_by_name('Appointment date').concept_id,
            type.id, params[:encounter]["patient_id"],session_date.strftime("%Y-%m-%d 00:00:00"),
            session_date.strftime("%Y-%m-%d 23:59:59")]).encounter
        appointment_encounter.void("Given a new appointment date")
      end

      if params[:encounter]['encounter_type_name'] == 'TB_INITIAL'
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'TRANSFER IN' and observation['value_coded_or_text'] == "YES"
            params[:observations] << {"concept_name" => "TB STATUS","value_coded_or_text" => "Confirmed TB on treatment"}
          end
        end
      end

      if params[:encounter]['encounter_type_name'] == 'HIV_CLINIC_REGISTRATION'

        has_tranfer_letter = false
        (params[:observations]).each do |ob|
          if ob["concept_name"] == "HAS TRANSFER LETTER"
            has_tranfer_letter = (ob["value_coded_or_text"].upcase == "YES")
            break
          end
        end
        if params[:observations][0]['concept_name'].upcase == 'EVER RECEIVED ART' and params[:observations][0]['value_coded_or_text'].upcase == 'NO'
          observations = []
          (params[:observations] || []).each do |observation|
            next if observation['concept_name'].upcase == 'HAS TRANSFER LETTER'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
            next if observation['concept_name'].upcase == 'ART NUMBER AT PREVIOUS LOCATION'
            next if observation['concept_name'].upcase == 'DATE ART LAST TAKEN'
            next if observation['concept_name'].upcase == 'LAST ART DRUGS TAKEN'
            next if observation['concept_name'].upcase == 'TRANSFER IN'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
            observations << observation
          end
        elsif params[:observations][4]['concept_name'].upcase == 'DATE ART LAST TAKEN' and params[:observations][4]['value_datetime'] != 'Unknown'
          observations = []
          (params[:observations] || []).each do |observation|
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
            observations << observation
          end
        end

        params[:observations] = observations unless observations.blank?

        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'LOCATION OF ART INITIATION' or observation['concept_name'].upcase == 'CONFIRMATORY HIV TEST LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end
          observations << observation
        end

        params[:observations] = observations unless observations.blank?
        observations = []
        vitals_observations = []
        initial_observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'WHO STAGES CRITERIA PRESENT'
            observations << observation
          elsif observation['concept_name'].upcase == 'WHO STAGES CRITERIA PRESENT'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT LOCATION'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT DATETIME'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT LESS THAN OR EQUAL TO 250'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT LESS THAN OR EQUAL TO 350'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 PERCENT'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 PERCENT LESS THAN 25'
            observations << observation
          elsif observation['concept_name'].upcase == 'REASON FOR ART ELIGIBILITY'
            observations << observation
          elsif observation['concept_name'].upcase == 'WHO STAGE'
            observations << observation
          elsif observation['concept_name'].upcase == 'BODY MASS INDEX, MEASURED'
            bmi = nil
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "BODY MASS INDEX, MEASURED"
                bmi = ob["value_numeric"]
                break
              end
            end
            next if bmi.blank?
            vitals_observations << observation
          elsif observation['concept_name'].upcase == 'WEIGHT (KG)'
            weight = 0
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "WEIGHT (KG)"
                weight = ob["value_numeric"].to_f rescue 0
                break
              end
            end
            next if weight.blank? or weight < 1
            vitals_observations << observation
          elsif observation['concept_name'].upcase == 'HEIGHT (CM)'
            height = 0
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "HEIGHT (CM)"
                height = ob["value_numeric"].to_i rescue 0
                break
              end
            end
            next if height.blank? or height < 1
            vitals_observations << observation
          else
            initial_observations << observation
          end
        end if has_tranfer_letter

        date_started_art = nil
        (initial_observations || []).each do |ob|
          if ob['concept_name'].upcase == 'DATE ANTIRETROVIRALS STARTED'
            date_started_art = ob["value_datetime"].to_date rescue nil
            if date_started_art.blank?
              date_started_art = ob["value_coded_or_text"].to_date rescue nil
            end
          end
        end
        unless vitals_observations.blank?
          encounter = Encounter.new()
          encounter.encounter_type = EncounterType.find_by_name("VITALS").id
          encounter.patient_id = params[:encounter]['patient_id']
          encounter.encounter_datetime = date_started_art
          if encounter.encounter_datetime.blank?
            encounter.encounter_datetime = params[:encounter]['encounter_datetime']
          end
          if params[:filter] and !params[:filter][:provider].blank?
            user_person_id = User.find_by_username(params[:filter][:provider]).person_id
          else
            user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
          end
          encounter.provider_id = user_person_id
          encounter.save
          params[:observations] = vitals_observations
          create_obs(encounter , params)
        end

        unless observations.blank?
          encounter = Encounter.new()
          encounter.encounter_type = EncounterType.find_by_name("HIV STAGING").id
          encounter.patient_id = params[:encounter]['patient_id']
          encounter.encounter_datetime = date_started_art
          if encounter.encounter_datetime.blank?
            encounter.encounter_datetime = params[:encounter]['encounter_datetime']
          end
          if params[:filter] and !params[:filter][:provider].blank?
            user_person_id = User.find_by_username(params[:filter][:provider]).person_id
          else
            user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
          end
          encounter.provider_id = user_person_id
          encounter.save

          params[:observations] = observations
          (params[:observations] || []).each do |observation|
            if observation['concept_name'].upcase == 'CD4 COUNT' or observation['concept_name'].upcase == "LYMPHOCYTE COUNT"
              observation['value_modifier'] = observation['value_numeric'].match(/=|>|</i)[0] rescue nil
              observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
            end
          end
          create_obs(encounter , params)
        end
        params[:observations] = initial_observations if has_tranfer_letter
      end

      if params[:encounter]['encounter_type_name'].upcase == 'HIV STAGING'
        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'CD4 COUNT' or observation['concept_name'].upcase == "LYMPHOCYTE COUNT"
            observation['value_modifier'] = observation['value_numeric'].match(/=|>|</i)[0] rescue nil
            observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
          end
          if observation['concept_name'].upcase == 'CD4 COUNT LOCATION' or observation['concept_name'].upcase == 'LYMPHOCYTE COUNT LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end
          if observation['concept_name'].upcase == 'CD4 PERCENT LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end

          observations << observation
        end

        params[:observations] = observations unless observations.blank?
      end

      if params[:encounter]['encounter_type_name'].upcase == 'ART ADHERENCE'
        previous_hiv_clinic_consultation_observations = []
        art_adherence_observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'REFER TO ART CLINICIAN'
            previous_hiv_clinic_consultation_observations << observation
          elsif observation['concept_name'].upcase == 'PRESCRIBE DRUGS'
            previous_hiv_clinic_consultation_observations << observation
          elsif observation['concept_name'].upcase == 'ALLERGIC TO SULPHUR'
            previous_hiv_clinic_consultation_observations << observation
          else
            art_adherence_observations << observation
          end
        end

        unless previous_hiv_clinic_consultation_observations.blank?
          #if "REFER TO ART CLINICIAN","PRESCRIBE DRUGS" and "ALLERGIC TO SULPHUR" has
          #already been asked during HIV CLINIC CONSULTATION - we append the observations to the latest
          #HIV CLINIC CONSULTATION encounter done on that day

          session_date = session[:datetime].to_date rescue Date.today
          encounter_type = EncounterType.find_by_name("HIV CLINIC CONSULTATION")
          encounter = Encounter.find(:first,:order =>"encounter_datetime DESC,date_created DESC",
            :conditions =>["encounter_type=? AND patient_id=? AND encounter_datetime >= ?
          AND encounter_datetime <= ?",encounter_type.id,params[:encounter]['patient_id'],
              session_date.strftime("%Y-%m-%d 00:00:00"),session_date.strftime("%Y-%m-%d 23:59:59")])
          if encounter.blank?
            encounter = Encounter.new()
            encounter.encounter_type = encounter_type.id
            encounter.patient_id = params[:encounter]['patient_id']
            encounter.encounter_datetime = session_date.strftime("%Y-%m-%d 00:00:01")
            if params[:filter] and !params[:filter][:provider].blank?
              user_person_id = User.find_by_username(params[:filter][:provider]).person_id
            else
              user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
            end
            encounter.provider_id = user_person_id
            encounter.save
          end
          params[:observations] = previous_hiv_clinic_consultation_observations
          create_obs(encounter , params)
        end
        params[:observations] = art_adherence_observations

        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
            observation['value_numeric'] = observation['value_text'] rescue nil
            observation['value_text'] =  ""
          end

          if observation['concept_name'].upcase == 'MISSED HIV DRUG CONSTRUCT'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_coded_or_text'] = ""
          end
          observations << observation
        end
        params[:observations] = observations unless observations.blank?
      end

      if params[:encounter]['encounter_type_name'].upcase == 'REFER PATIENT OUT?'
        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'REFERRAL CLINIC IF REFERRED'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end

          observations << observation
        end

        params[:observations] = observations unless observations.blank?
      end

      @patient = Patient.find(params[:encounter][:patient_id]) rescue nil
      if params[:location]
        if @patient.nil?
          @patient = Patient.find_with_voided(params[:encounter][:patient_id])
        end

        Person.migrated_datetime = params[:encounter]['date_created']
        Person.migrated_creator  = params[:encounter]['creator'] rescue nil

        # set current location via params if given
        Location.current_location = Location.find(params[:location])
      end

      if params[:encounter]['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
        concept_id = ConceptName.find_by_name("RETURN VISIT DATE").concept_id
        encounter_id_s = Observation.find_by_sql("SELECT encounter_id
                       FROM obs
                       WHERE concept_id = #{concept_id} AND person_id = #{@patient.id}
                            AND DATE(value_datetime) = DATE('#{params[:old_appointment]}') AND voided = 0
          ").map{|obs| obs.encounter_id}.each do |encounter_id|
          Encounter.find(encounter_id).void
        end
      end

      # Encounter handling
      encounter = Encounter.new(params[:encounter])
      unless params[:location]
        encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
      else
        encounter.encounter_datetime = params[:encounter]['encounter_datetime']
      end

      if params[:filter] and !params[:filter][:provider].blank?
        user_person_id = User.find_by_username(params[:filter][:provider]).person_id
      elsif params[:location] # Migration
        user_person_id = encounter[:provider_id]
      else
        user_person_id = User.find_by_user_id(encounter[:provider_id]).person_id
      end
      encounter.provider_id = user_person_id

      encounter.save
      #create observations for the just created encounter
      create_obs(encounter , params)

      if !params[:recalculate_bmi].blank? && params[:recalculate_bmi] == "true"
        weight = 0
        height = 0

        weight_concept_id  = ConceptName.find_by_name("Weight (kg)").concept_id
        height_concept_id  = ConceptName.find_by_name("Height (cm)").concept_id
        bmi_concept_id = ConceptName.find_by_name("Body mass index, measured").concept_id
        work_station_concept_id = ConceptName.find_by_name("Workstation location").concept_id

        vitals_encounter_id = EncounterType.find_by_name("VITALS").encounter_type_id
        enc = Encounter.find(:all, 
          :conditions => ["encounter_type = ? AND patient_id = ? AND voided = 0", 
          vitals_encounter_id, @patient.id])

        encounter.observations.each do |o|
          height = o.answer_string.squish if o.concept_id == height_concept_id
        end

        enc.each do |e|
          obs_created = false
          weight = nil

          e.observations.each do |o|
            next if o.concept_id == work_station_concept_id

            if o.concept_id == weight_concept_id
              weight = o.answer_string.squish.to_i
            elsif o.concept_id == height_concept_id || o.concept_id == bmi_concept_id
              o.voided = 1
              o.date_voided = Time.now
              o.voided_by = encounter.creator
              o.void_reason = "Back data entry recalculation"
              o.save
            end
          end

          bmi = (weight.to_f/(height.to_f*height.to_f)*10000).round(1) rescue "Unknown"

          field = :value_numeric
          field = :value_text and height = 'Unknown' if height == 'Unknown' || height.to_i == 0

          height_obs = Observation.new(
            :concept_name => "Height (cm)",
            :person_id => @patient.id,
            :encounter_id => e.id,
            field => height,
            :obs_datetime => e.encounter_datetime)

          height_obs.save

          field = :value_numeric
          field = :value_text and bmi = 'Unknown' if bmi == 'Unknown' || bmi.to_i == 0

          bmi_obs = Observation.new(
            :concept_name => "Body mass index, measured",
            :person_id => @patient.id,
            :encounter_id => e.id,
            field => bmi,
            :obs_datetime => e.encounter_datetime)

          bmi_obs.save
        end
      end

      # Program handling
      date_enrolled = params[:programs][0]['date_enrolled'].to_time rescue nil
      date_enrolled = session[:datetime] || Time.now() if date_enrolled.blank?
      (params[:programs] || []).each do |program|
        # Look up the program if the program id is set
        @patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?

        #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #if params[:location] is not blank == migration params
        if params[:location]
          next if not @patient.patient_programs.in_programs("HIV PROGRAM").blank?
        end
        #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # If it wasn't set, we need to create it
        unless (@patient_program)
          @patient_program = @patient.patient_programs.create(
            :program_id => program[:program_id],
            :date_enrolled => date_enrolled)
        end
        # Lots of states bub
        unless program[:states].blank?
          #adding program_state start date
          program[:states][0]['start_date'] = date_enrolled
        end
        (program[:states] || []).each {|state| @patient_program.transition(state) }
      end

      # Identifier handling
      arv_number_identifier_type = PatientIdentifierType.find_by_name('ARV Number').id
      (params[:identifiers] || []).each do |identifier|
        # Look up the identifier if the patient_identfier_id is set
        @patient_identifier = PatientIdentifier.find(identifier[:patient_identifier_id]) unless identifier[:patient_identifier_id].blank?
        # Create or update
        type = identifier[:identifier_type].to_i rescue nil
        unless (arv_number_identifier_type != type) and @patient_identifier
          arv_number = identifier[:identifier].strip
          if arv_number.match(/(.*)[A-Z]/i).blank?
            if params[:encounter]['encounter_type_name'] == 'TB REGISTRATION'
              identifier[:identifier] = "#{PatientIdentifier.site_prefix}-TB-#{arv_number}"
            else
              identifier[:identifier] = "#{PatientIdentifier.site_prefix}-ARV-#{arv_number}"
            end
          end
        end

        if @patient_identifier
          @patient_identifier.update_attributes(identifier)
        else
          @patient_identifier = @patient.patient_identifiers.create(identifier)
        end
      end

      # person attribute handling
      (params[:person] || []).each do | type , attribute |
        # Look up the attribute if the person_attribute_id is set
        @person_attribute = nil

        if not @person_attribute.blank?
          @patient_identifier.update_attributes(person_attribute)
        else
          case type
          when 'agrees_to_be_visited_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
              :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to be visited at home for TB therapy").person_attribute_type_id,
              :value => attribute)
          when 'agrees_phone_text_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
              :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to phone text for TB therapy").person_attribute_type_id,
              :value => attribute)
          end
        end
      end

      render :text => "OK"

    else
      render :text => "Location not found or not valid"
    end
  end 

  def export_on_art_patients
		@ids = params["ids"].split(",")
		@id_string = "'" + @ids.join("','") + "'"
		@end_date = params["end_date"]
		@start_date = params["start_date"]
    anc_visit = Hash.new
    params["id_visit_map"].split(",").each do |map|
      anc_visit["#{map.split('|').first}"] = map.split('|').last
    end
    result = Hash.new
    @patient_ids = []
    b4_visit_one = []
    PatientProgram.find_by_sql("SELECT e.patient_id, f.identifier, e.earliest_start_date, current_state_for_program(e.patient_id, 1, '#{@end_date}') AS state
			FROM earliest_start_date e
			JOIN person p ON p.person_id = e.patient_id
            JOIN patient_identifier f ON f.patient_id = p.person_id AND f.identifier_type = (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'National id') AND f.identifier IN (#{@id_string})
			WHERE p.gender regexp 'F'
			HAVING state = 7").each do | patient |
      @patient_ids << patient.patient_id
      idf = patient.identifier
      result["#{idf}"] = patient.earliest_start_date
      b4_visit_one << idf if patient.earliest_start_date.to_date <= anc_visit["#{idf}"].to_date
    end
    if @patient_ids.length > 0
  		cpt_ids = Encounter.find_by_sql("SELECT e.patient_id, o.value_drug, e.encounter_type FROM encounter e
			INNER JOIN obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
			WHERE e.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'DISPENSING')
			AND o.value_drug IN (SELECT drug_id FROM drug WHERE name regexp 'cotrimoxazole')
			AND e.patient_id IN (#{@patient_ids.join(',')})").collect{|e| PatientIdentifier.find(:first, :conditions => ["patient_id = ? AND identifier_type = ?", e.patient_id, PatientIdentifierType.find_by_name("National id").id]).identifier}.uniq rescue []
    else
      cpt_ids = []
    end

		result["on_cpt"] = cpt_ids.join(",")
    result["arv_before_visit_one"] = b4_visit_one.join(",")

		render :text => result.to_json
  end


	def lab_results_print
		label_commands = lab_results_label(params[:id])
		send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbs", :disposition => "inline")

	end

  def lab_results_label(patient_id)
		patient = Patient.find(patient_id)
		patient_bean = PatientService.get_patient(patient.person)

		begin
			observation = patient_recent_lab_results(patient_id)
			sputum_results = [['NEGATIVE','NEGATIVE'], ['SCANTY','SCANTY'], ['WEAKLY POSITIVE','1+'], ['MODERATELY POSITIVE','2+'], ['STRONGLY POSITIVE','3+']]
			concept_one = ConceptName.find_by_name("First sputum for AAFB results").concept_id
			concept_two = ConceptName.find_by_name("Second sputum for AAFB results").concept_id
			concept_three = ConceptName.find_by_name("Third sputum for AAFB results").concept_id
			concept_four = ConceptName.find_by_name("Culture(1st) Results").concept_id
			concept_five = ConceptName.find_by_name("Culture(2nd) Results").concept_id
			concept =[]
			culture =[]
			labels = []
			observation.each do |obs|
						next if obs.value_coded.blank?
						concept[0] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_one
						concept[1] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_two
						concept[2] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_three
						culture[0] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_four
						culture[1] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_five
			end
			if concept.length < 2
						first = "Culture-1 Results: #{sputum_results.assoc("#{culture[0].upcase}")[1]}"
						second = "Culture-2 Results: #{sputum_results.assoc("#{culture[1].upcase}")[1]}"
			else
						lab_result = []
						h = 0
						(0..2).each do |x|
									if concept[x].to_s != ""
									lab_result[h] = sputum_results.assoc("#{concept[x].upcase}")
									h += 1
									end
						end
						first = "AAFB(1st) results: #{lab_result[0][1] rescue ""}"
						second = "AAFB(2nd) results: #{lab_result[1][1] rescue ""}"
						end
						i = 0
    labels = []

          label = 'label' + i.to_s
          label = ZebraPrinter::Label.new(500,165)
          label.font_size = 2
          label.font_horizontal_multiplier = 1
          label.font_vertical_multiplier = 1
          label.left_margin = 300
          label.draw_text("Name: #{patient_bean.name}",50,50,0,3,1,1,false)
          label.draw_text(first,50,90,0,2,1,1)
          label.draw_text(second,50,130,0,2,1,1)

          labels << label

         i = i + 1

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(1) if labels[label] != nil
        label = label + 1
      end

      return print_labels
		rescue
			return
		end
  end

  protected

  def number_of_booked_patients(date)                          
                                                                                
    start_date = date.strftime('%Y-%m-%d 00:00:00')                             
    end_date = date.strftime('%Y-%m-%d 23:59:59')                               
                                                                                
    appointments = Observation.find_by_sql("SELECT count(value_datetime) AS count FROM obs 
      INNER JOIN encounter e USING(encounter_id) WHERE concept_id = #{@concept_id} 
      AND encounter_type = #{@encounter_type.id} AND value_datetime >= '#{start_date}' 
      AND value_datetime <= '#{end_date}' AND obs.voided = 0 GROUP BY value_datetime")     
    count = appointments.first.count unless appointments.blank?                       
    count = 0 if count.blank?                                                 
                                                                                
    return count
  end 	
end
