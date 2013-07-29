class GenericRegimensController < ApplicationController

	def new

		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end

		@patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
		@patient_bean = PatientService.get_patient(@patient.person)
		@programs = @patient.patient_programs.all
		#@hiv_programs = @patient.patient_programs.not_completed.in_programs('HIV PROGRAM')
    @hiv_programs = []
    @programs.each do |prog|
        if prog.program.name.upcase == "HIV PROGRAM"
          @hiv_programs << prog #unless ProgramWorkflowState.find_state(prog.patient_states.last.state).concept.fullname.match(/treatment stopped/i)
        end
    end

		@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
		@current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight")
		@tb_encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                    :conditions=>["patient_id = ? AND encounter_type = ?", 
                    @patient.id, EncounterType.find_by_name("TB visit").id], 
                    :include => [:observations]) rescue nil

		@tb_programs = @patient.patient_programs.in_uncompleted_programs(['TB PROGRAM', 'MDR-TB PROGRAM'])
		
		@current_regimens_for_programs = current_regimens_for_programs
    @regimen_formulations = []
		@tb_regimen_formulations = []
		
    (@current_regimens_for_programs || {}).each do |patient_program_id , regimen_id|
      @regimen_formulations = formulation(@patient,regimen_id) if PatientProgram.find(patient_program_id).program.name.match(/HIV PROGRAM/i)
			@hiv_regimen_map = regimen_id if PatientProgram.find(patient_program_id).program.name.match(/HIV PROGRAM/i)
			@tb_regimen_formulations = formulation(@patient,regimen_id) if PatientProgram.find(patient_program_id).program.name.match(/TB PROGRAM/i)
    end
		@current_regimen_names_for_programs = current_regimen_names_for_programs
		
		@current_hiv_program_state = PatientProgram.find(:first, :joins => :location, 
                                 :conditions => ["patient_id = ? AND program_id = ? AND location.location_id = ? AND date_completed IS NULL",
                                  @patient.id, Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id, Location.current_health_center]).patient_states.current.first.program_workflow_state.concept.fullname rescue ''
		session_date = session[:datetime].to_date rescue Date.today
    #raise Location.current_health_center.id.to_yaml

    #raise PatientProgram.find(:first, :joins => :location,
    #                          :conditions => ["patient_id = ? AND program_id = ? AND location.location_id = ? AND date_completed IS NULL", @patient.id, Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id, Location.current_health_center.id]).to_yaml
		pre_hiv_clinic_consultation = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
		    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
		    session_date.to_date, @patient.id, EncounterType.find_by_name('PART_FOLLOWUP').id])

		hiv_clinic_consultation = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
            :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date, @patient.id, EncounterType.find_by_name('HIV CLINIC CONSULTATION').id])
		@hiv_clinic_consultation = false

		if ((not pre_hiv_clinic_consultation.blank?) or (not hiv_clinic_consultation.blank?))
			@hiv_clinic_consultation = true		
		end

		treatment_obs = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
		    :conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
		    session_date, @patient.id, EncounterType.find_by_name('TREATMENT').id]).observations rescue []

		tb_medication_prescribed = false
		arvs_prescribed = false
		(treatment_obs || []).each do | obs | 
			if obs.concept_id == (Concept.find_by_name('TB regimen type').concept_id rescue nil)
				tb_medication_prescribed = true 
			end

			if obs.concept_id == (Concept.find_by_name('ARV regimen type').concept_id rescue nil)
				arvs_prescribed = true 
			end
		end

		tb_visit_obs = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
		    :conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
		    session_date, @patient.id, EncounterType.find_by_name('TB VISIT').id]).observations rescue []

		prescribe_tb_medication = false
		@transfer_out_patient = false;
		(tb_visit_obs || []).each do | obs | 
			if obs.concept_id == (Concept.find_by_name('Prescribe drugs').concept_id rescue nil)
				prescribe_tb_medication = true if Concept.find(obs.value_coded).fullname.upcase == 'YES' 
			end

			if obs.concept_id == (Concept.find_by_name('Continue treatment').concept_id rescue nil)
				@transfer_out_patient = true if Concept.find(obs.value_coded).fullname.upcase == 'NO' 
			end
		end
		
		@prescribe_tb_drugs = false	
		if (not @tb_programs.blank?) and prescribe_tb_medication and !tb_medication_prescribed
			@prescribe_tb_drugs = true
		end

		sulphur_allergy_obs = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
			:conditions => ["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
			@patient.id, EncounterType.find(:all,:select => 'encounter_type_id', 
      :conditions => ["name IN (?)",["HIV CLINIC CONSULTATION", "TB VISIT"]]),session_date.to_date]).observations rescue []

		@alergic_to_suphur = false
		(sulphur_allergy_obs || []).each do | obs |
			if obs.concept_id == (Concept.find_by_name('sulphur allergy').concept_id rescue nil)
				@alergic_to_suphur = true if Concept.find(obs.value_coded).fullname.upcase == 'YES'
			end
		end

		hiv_clinic_consultation_obs = Encounter.find(:first,
      :order => "encounter_datetime DESC,date_created DESC",
			:conditions => ["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
			@patient.id, EncounterType.find(:all,:select => 'encounter_type_id', 
      :conditions => ["name IN (?)",["HIV CLINIC CONSULTATION"]]),session_date.to_date]).observations rescue []

		concept_id = concept_id = ConceptName.find_by_name("COMMON MALAWI ART SYMPTOM SET").concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    hiv_symptoms_ids = set.map{|item|next if item.concept.blank? ; item.concept_id }

		concept_id = concept_id = ConceptName.find_by_name("ADDITIONAL MALAWI ART SYMPTOM SET").concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    hiv_additional_symptoms_ids = set.map{|item|next if item.concept.blank? ; item.concept_id }

		hiv_symptoms_ids += hiv_additional_symptoms_ids
		@found_symptoms = []

		@prescribe_art_drugs = false
		(hiv_clinic_consultation_obs || []).each do | obs |
			if obs.concept_id == (Concept.find_by_name('Prescribe drugs').concept_id rescue nil)
				@prescribe_art_drugs = true if Concept.find(obs.value_coded).fullname.upcase == 'YES' and !arvs_prescribed
			end
			if hiv_symptoms_ids.include?(obs.value_coded) and !@found_symptoms.include?(Concept.find(obs.value_coded).fullname.upcase.to_s)
					@found_symptoms += [Concept.find(obs.value_coded).fullname.upcase.to_s]
			end
		end

		@adverse_events = regimen_options
		@regimen_index = Regimen.find_by_sql("select distinct(c.name) as name, r.regimen_index as reg_index from concept_name c
										inner join regimen r on r.concept_id = c.concept_id
										where c.concept_id = '#{@hiv_regimen_map}' and  concept_name_type = 'short' limit 1").map{|regimen| regimen.reg_index}

	    session_date = session[:datetime].to_date rescue Date.today
        current_encounters = @patient.encounters.find_by_date(session_date)
        @family_planning_methods = []
        @is_patient_pregnant_value = 'Unknown'

        for encounter in current_encounters.reverse do

            if encounter.name.humanize.include?('Hiv staging') || encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation') 
             
                encounter = Encounter.find(encounter.id, :include => [:observations])

                for obs in encounter.observations do
                    if obs.concept_id == ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
                        @is_patient_pregnant_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
                    end                    
                end

                if encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation')

                    encounter = Encounter.find(encounter.id, :include => [:observations])
                    for obs in encounter.observations do
                        if obs.concept_id == ConceptName.find_by_name("CURRENTLY USING FAMILY PLANNING METHOD").concept_id
                            @currently_using_family_planning_methods = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
                        end

                        if obs.concept_id == ConceptName.find_by_name("FAMILY PLANNING METHOD").concept_id
                            @family_planning_methods << "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish.humanize
                        end
                    end
                    
                end
                
            end
        end
	end

  def check_current_regimen_index
		session_date = session[:datetime].to_date rescue Date.today
		patient_program = PatientProgram.find(params[:id])
		options = []
		current_weight = PatientService.get_patient_attribute_value(patient_program.patient, "current_weight", session_date)
		options = MedicationService.regimen_options(current_weight, patient_program.program)
		render :text => (options.to_json)
	end

	def regimen_options
    adverse_options = {
      '1' => { 'adverse' => [
        ['Neuropathy','Neuropathy'],
        ['Hepatitis, Skin rash','Hepatitis, Skin rash'],
        ['Lipodystrophy, Lactic acidocis','Lipodystrophy, Lactic acidocis'],
        ['Treatment failure','Treatment failure']
      ],
				'contraindications' => [
					['Hepatitis/Jaundice','Hepatitis/Jaundice']
				],
				'alt1' => [
				['Neuropathy','2'],
        ['Hepatitis, Skin rash','3'],
        ['Lipodystrophy, Lactic acidocis','5'],
        ['Treatment failure','7']
				],
				'alt2'=> [
				['Neuropathy','5 or 6'],
        ['Hepatitis, Skin rash',' None'],
        ['Lipodystrophy, Lactic acidocis','NS'],
        ['Treatment failure','9']
				]
			},
			'2' => { 'adverse' =>[
				['Hepatitis, Skin rash','Hepatitis, Skin rash'],
				['Treatment failure','Treatment failure'],
				['Lipodystrophy, Lactic acidocis','Lipodystrophy, Lactic acidocis'],
				['Anemia','Anemia']
			],
				'contraindications' => [
					['Hepatitis/Jaundice','Hepatitis/Jaundice'],
					['Anaemia <8g/dl','Anaemia <8g/dl']
				],
				'alt1' => [
				['Hepatitis, Skin rash','4'],
				['Treatment failure','7'],
				['Lipodystrophy, Lactic acidocis','5'],
				['Anemia','1']
				],
				'alt2'=> [
				['Hepatitis, Skin rash','3'],
				['Treatment failure','9'],
				['Lipodystrophy, Lactic acidocis','NS'],
				['Anemia','5 or 6']
				]},
			'3' => { 'adverse' =>[
				['Neuropathy','Neuropathy'],
				['Hepatitis, Skin rash, psychiat disorder','Hepatitis, Skin rash, psychiat disorder'],
				['Lipodystrophy, Lactic acidocis','Lipodystrophy, Lactic acidocis'],
				['Treatment failure','Treatment failure']
			],
				'contraindications' => [
					['History of psychiatric illness','History of psychiatric illness']
				],
				'alt1' => [
				['Neuropathy','2'],
				['Hepatitis, Skin rash, psychiat disorder','1'],
				['Lipodystrophy, Lactic acidocis','5'],
				['Treatment failure','7']
				],
				'alt2'=> [
				['Neuropathy','5 or 6 or NS'],
				['Hepatitis, Skin rash, psychiat disorder','NS'],
				['Lipodystrophy, Lactic acidocis','None'],
				['Treatment failure','None']
				]},
			'4' => { 'adverse' => [
				['Anemia','Anemia'],
				['Lipodystrophy, Lactic acidocis','Lipodystrophy, Lactic acidocis'],
				['Hepatitis, Skin rash, psychiat disorder','Hepatitis, Skin rash, psychiat disorder'],
				['Treatment failure','Treatment failure']
			],
				'contraindications' => [
					['History of psychiatric illness','History of psychiatric illness'],
					['Anaemia <8g/dl','Anaemia <8g/dl']
				],
				'alt1' => [
				['Anemia','3'],
				['Lipodystrophy, Lactic acidocis','5'],
				['Hepatitis, Skin rash, psychiat disorder','2'],
				['Treatment failure','7']
				],
				'alt2'=> [
				['Anemia','5'],
				['Lipodystrophy, Lactic acidocis','9'],
				['Hepatitis, Skin rash, psychiat disorder','NS'],
				['Treatment failure','9']
				]},
			'5' => { 'adverse' =>[
				['Renal Failure','Renal Failure'],
				['Hepatitis, Skin rash, psychiat disorder','Hepatitis, Skin rash, psychiat disorder'],
				['Treatment failure','Treatment failure']
				],
				'contraindications' => [
					['History of psychiatric illness','History of psychiatric illness'],
					['Renal failure','Renal failure'],
					['Child under 12 years','Child under 12 years']
				],
				'alt1' => [
				['Renal Failure','Lower dose'],
				['Hepatitis, Skin rash, psychiat disorder','6'],
				['Treatment failure','8']
				],
				'alt2'=> [
				['Renal Failure','2'],
				['Hepatitis, Skin rash, psychiat disorder','NS'],
				['Treatment failure','None']
				]},
			'6' => { 'adverse' =>[
				['Renal failure','Renal failure'],
				['Hepatitis, Skin rash','Hepatitis, Skin rash'],
				['Treatment failure','Treatment failure']
				],
				'contraindications' => [
					['Hepatitis/Jaundice','Hepatitis/Jaundice'],
					['Renal failure','Renal failure'],
					['Child under 12 years','Child under 12 years']
				],
				'alt1' => [
				['Renal failure','Lower dose'],
				['Hepatitis, Skin rash','5'],
				['Treatment failure','8']
				],
				'alt2'=> [
				['Renal failure','2'],
				['Hepatitis, Skin rash','NS'],
				['Treatment failure','None']
				]},
			'7' =>{ 'adverse' =>[
				['Nausia, vomiting','Nausia, vomiting'],
				['Renal failure','Renal failure'],
				['Treatment failure','Treatment failure']
				],
				'contraindications' => [
					['Renal failure','Renal failure'],
					['Child under 12 years','Child under 12 years']
				],
				'alt1' => [
				['Nausia, vomiting','8'],
				['Renal failure','NS'],
				['Treatment failure','None']
				],
				'alt2'=> [
				['Nausia, vomiting','None'],
				['Renal failure','None'],
				['Treatment failure','(3rd line)']
				]},
			'8' => { 'adverse' => [
				['Nausia, vomiting','Nausia, vomiting'],
				['Anemia','Anemia'],
				['Treatment failure','Treatment failure']
				],
				'contraindications' => [
					['Anaemia <8g/dl','Anaemia <8g/dl']
				],
				'alt1' => [
				['Nausia, vomiting','7'],
				['Anemia','NS'],
				['Treatment failure','None']
				],
				'alt2'=> [
				['Nausia, vomiting','None'],
				['Anemia','None'],
				['Treatment failure','(3rd line)']
				]},
			'9' => { 'adverse' =>[
				['ABC hypersensitivity','ABC hypersensitivity'],
				['Treatment failure','Treatment failure']
				],
				'contraindications' => [
					['Abacavir hypersensitivity','Abacavir hypersensitivity']
				],
				'alt1' => [
				['ABC hypersensitivity','8 or 7'],
				['Treatment failure','None']
				],
				'alt2'=> [
				['ABC hypersensitivity','None'],
				['Treatment failure','(3rd line)']
				]
				}

		}

	end

	def create
		#raise params[:ipt_mgs].to_yaml
		prescribe_tb_drugs = false   
		prescribe_tb_continuation_drugs = false   
		prescribe_arvs = false
		prescribe_cpt = false
		prescribe_ipt = false
		clinical_notes = nil
		condoms = nil
		reason = nil
		(params[:observations] || []).each do |observation|
			if observation['concept_name'].upcase == 'PRESCRIBE DRUGS'
				prescribe_tb_drugs = ('YES' == observation['value_coded_or_text'])
				prescribe_tb_continuation_drugs = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'PRESCRIBE ARVS'
				prescribe_arvs = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'Prescribe cotramoxazole'
				prescribe_cpt = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'ISONIAZID'
				prescribe_ipt = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'CLINICAL NOTES CONSTRUCT'
				clinical_notes = observation['value_text']
			elsif observation['concept_name'] == 'CONDOMS'
				condoms = observation['value_numeric']
			elsif observation['concept_name'] == 'Reason antiretrovirals changed or stopped'
				reason = observation['value_coded_or_text']
			end
		end
		#raise prescribe_arvs.to_yaml
		@patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
		session_date = session[:datetime] || Time.now()

		if !params[:filter][:provider].blank?
			user_person_id = User.find_by_username(params[:filter][:provider]).person_id
		else
			user_person_id = current_user.person_id
		end

		user_person_id = user_person_id rescue User.find_by_user_id(current_user.user_id).person_id

		encounter = PatientService.current_treatment_encounter(@patient, session_date, user_person_id)
		start_date = session[:datetime] || Time.now
		arvs_buffer = 2
		auto_expire_date = session[:datetime] + params[:duration].to_i.days + arvs_buffer.days rescue Time.now + params[:duration].to_i.days + arvs_buffer.days
		auto_tb_expire_date = session[:datetime] + params[:tb_duration].to_i.days rescue Time.now + params[:tb_duration].to_i.days
		auto_tb_continuation_expire_date = session[:datetime] + params[:tb_continuation_duration].to_i.days rescue Time.now + params[:tb_continuation_duration].to_i.days
		auto_cpt_ipt_expire_date = session[:datetime] + params[:duration].to_i.days rescue Time.now + params[:duration].to_i.days


		orders = RegimenDrugOrder.all(:conditions => {:regimen_id => params[:tb_regimen]})
		ActiveRecord::Base.transaction do
			# Need to write an obs for the regimen they are on, note that this is ARV
			# Specific at the moment and will likely need to have some kind of lookup
			# or be made generic
			obs = Observation.create(
				:concept_name => "WHAT TYPE OF TUBERCULOSIS REGIMEN",
				:person_id => @patient.person.person_id,
				:encounter_id => encounter.encounter_id,
				:value_coded => params[:tb_regimen_concept_id],
				:obs_datetime => start_date) if prescribe_tb_drugs
			orders.each do |order|
				drug = Drug.find(order.drug_inventory_id)
				regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept.name).name
				DrugOrder.write_order(
					encounter, 
					@patient, 
					obs, 
					drug, 
					start_date, 
					auto_tb_expire_date, 
					order.dose, 
					order.frequency, 
					order.prn,
  				"#{drug.name}: #{order.instructions} (#{regimen_name})",
					order.equivalent_daily_dose)  
			end if prescribe_tb_drugs
		end

		orders = RegimenDrugOrder.all(:conditions => {:regimen_id => params[:tb_continuation_regimen]})
		ActiveRecord::Base.transaction do
			# Need to write an obs for the regimen they are on, note that this is ARV
			# Specific at the moment and will likely need to have some kind of lookup
			# or be made generic
			obs = Observation.create(
				:concept_name => "WHAT TYPE OF TUBERCULOSIS REGIMEN",
				:person_id => @patient.person.person_id,
				:encounter_id => encounter.encounter_id,
				:value_coded => params[:tb_continuation_regimen_concept_id],
				:obs_datetime => start_date) if prescribe_tb_continuation_drugs
			orders.each do |order|
				drug = Drug.find(order.drug_inventory_id)
				regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept.name).name
				DrugOrder.write_order(
					encounter, 
					@patient, 
					obs, 
					drug, 
					start_date, 
					auto_tb_continuation_expire_date, 
					order.dose, 
					order.frequency, 
					order.prn, 
					"#{drug.name}: #{order.instructions} (#{regimen_name})",
					order.equivalent_daily_dose)  
			end if prescribe_tb_continuation_drugs
		end

		reduced = false
		orders = RegimenDrugOrder.all(:conditions => {:regimen_id => params[:regimen]})
		ActiveRecord::Base.transaction do
			# Need to write an obs for the regimen they are on, note that this is ARV
			# Specific at the moment and will likely need to have some kind of lookup
			# or be made generic
			selected_regimen = Regimen.find(params[:regimen]) if prescribe_arvs
 
			obs = Observation.create(
				:concept_name => "REGIMEN CATEGORY",
				:person_id => @patient.person.person_id,
				:encounter_id => encounter.encounter_id,
				:value_text => selected_regimen.regimen_index,
				:obs_datetime => start_date) if prescribe_arvs

			obs = Observation.create(
				:concept_name => "WHAT TYPE OF ANTIRETROVIRAL REGIMEN",
				:person_id => @patient.person.person_id,
				:encounter_id => encounter.encounter_id,
				:value_coded => params[:regimen_concept_id],
				:obs_datetime => start_date) if prescribe_arvs

			orders.each do |order|
				# Reduce buffer from 2 to 1 for starter packs
				if order.regimen.concept.shortname.upcase.match(/STARTER PACK/i) and !reduced
					reduced = true
					auto_expire_date  = auto_expire_date - 1.days
				end

				drug = Drug.find(order.drug_inventory_id)
				regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept.name).name
				DrugOrder.write_order(
				encounter, 
				@patient, 
				obs, 
				drug, 
				start_date, 
				auto_expire_date, 
				order.dose, 
				order.frequency, 
				order.prn, 
				"#{drug.name}: #{order.instructions} (#{regimen_name})",
				order.equivalent_daily_dose)    
			end if prescribe_arvs
		end

		['CPT STARTED','ISONIAZID'].each do | concept_name |
			if concept_name == 'ISONIAZID'
				concept = 'NO' unless prescribe_ipt
				concept = 'YES' if prescribe_ipt
			else
				concept = 'NO' unless prescribe_cpt
				concept = 'YES' if prescribe_cpt
			end
			yes_no = ConceptName.find_by_name(concept)
			obs = Observation.create(
				:concept_name => concept_name ,
				:person_id => @patient.person.person_id ,
				:encounter_id => encounter.encounter_id ,
				:value_coded => yes_no.concept_id ,
				:obs_datetime => start_date) 

			next if concept == 'NO'

      if ! params[:cpt_duration].blank?
        #params[:cpt_duration] =  params[:duration]
        auto_cpt_ipt_expire_date = session[:datetime] + params[:cpt_duration].to_i.days rescue Time.now + params[:cpt_duration].to_i.days
      end
			if concept_name == 'CPT STARTED'
				if params[:cpt_mgs] == "960"
					drug = Drug.find_by_name('Cotrimoxazole (960mg)')
				else
					drug = Drug.find_by_name('Cotrimoxazole (480mg tablet)')
				end
      else
				if params[:ipt_mgs] == "300"
						drug = Drug.find_by_name('INH or H (Isoniazid 300mg tablet)')	
				else
						drug = Drug.find_by_name('INH or H (Isoniazid 100mg tablet)')
				end	
			end
			
			weight = @current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight")
			regimen_id = Regimen.all(:conditions =>  ['min_weight <= ? AND max_weight >= ? AND concept_id = ?', weight, weight, drug.concept_id]).first.regimen_id

			#raise regimen_id.to_yaml

			orders = RegimenDrugOrder.all(:conditions => {:regimen_id => regimen_id})
			
					#raise auto_cpt_ipt_expire_date.to_yaml
					orders.each do |order|
						regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept_names.typed("FULLY_SPECIFIED").first).name
						DrugOrder.write_order(
						encounter,
						@patient,
						obs,
						drug,
						start_date,
						auto_cpt_ipt_expire_date,
						order.dose,
						order.frequency,
						order.prn,
						"#{drug.name}: #{order.instructions} (#{regimen_name})",
						order.equivalent_daily_dose)
					end
		end
		
		obs = Observation.create(
			:concept_name => "Reason antiretrovirals changed or stopped",
			:person_id => @patient.person.person_id,
			:encounter_id => encounter.encounter_id,
			:value_text => reason,
			:obs_datetime => start_date) if !reason.blank?

		obs = Observation.create(
			:concept_name => "CONDOMS",
			:person_id => @patient.person.person_id,
			:encounter_id => encounter.encounter_id,
			:value_numeric => condoms,
			:obs_datetime => start_date) if !condoms.blank?
		
		if !params[:transfer_data].nil?
			transfer_out_patient(params[:transfer_data][0])
		end
    
		# Send them back to treatment for now, eventually may want to go to workflow
		redirect_to "/patients/treatment_dashboard?patient_id=#{@patient.id}"
	end    

	def suggested
		session_date = session[:datetime].to_date rescue Date.today
		patient_program = PatientProgram.find(params[:id])
		@options = []
		render :layout => false and return unless patient_program
		current_weight = PatientService.get_patient_attribute_value(patient_program.patient, "current_weight", session_date)
		#regimen_concepts = patient_program.regimens(current_weight).uniq
		@options = MedicationService.regimen_options(current_weight, patient_program.program)
		render :layout => false
	end

	def dosing
		@patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
		@criteria = Regimen.criteria(PatientService.get_patient_attribute_value(@patient, "current_weight")).all(:conditions => {:concept_id => params[:id]}, :include => :regimen_drug_orders)
		@options = @criteria.map do |r| 
			[r.regimen_id, r.regimen_drug_orders.map(&:to_s).join('; ')]
		end
		render :layout => false    
	end

	def formulations
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @criteria = Regimen.criteria(PatientService.get_patient_attribute_value(@patient, "current_weight")).all(:conditions => {:concept_id => params[:id]}, :include => :regimen_drug_orders)
    @options = @criteria.map do | r |
      r.regimen_drug_orders.map do | order |
        [order.drug.name , order.dose, order.frequency , order.units , r.id ]
      end
    end
    render :text => @options.to_json 
	end

	# Look up likely durations for the regimen
	def durations
		@regimen = Regimen.find_by_concept_id(params[:id], :include => :regimen_drug_orders)
		@drug_id = @regimen.regimen_drug_orders.first.drug_inventory_id rescue nil
		render :text => "No matching durations found for regimen" and return unless @drug_id

		# Grab the 10 most popular durations for this drug
		amounts = []
		orders = DrugOrder.find(:all, 
			:select => 'DATEDIFF(orders.auto_expire_date, orders.start_date) as duration_days',
			:joins => 'LEFT JOIN orders ON orders.order_id = drug_order.order_id AND orders.voided = 0',
			:limit => 10, 
			:group => 'drug_inventory_id, DATEDIFF(orders.auto_expire_date, orders.start_date)', 
			:order => 'count(*)', 
			:conditions => {:drug_inventory_id => @drug_id})      
		orders.each {|order|
			amounts << "#{order.duration_days.to_f}" unless order.duration_days.blank?
		}  
		amounts = amounts.flatten.compact.uniq
		render :text => "<li>" + amounts.join("</li><li>") + "</li>"
	end

	private

	def current_regimens_for_programs
		@programs.inject({}) do |result, program| 
			result[program.patient_program_id] = program.current_regimen; result 
		end
	end

	def current_regimen_names_for_programs
		@programs.inject({}) do |result, program| 
	  		result[program.patient_program_id] = program.current_regimen ? Concept.find_by_concept_id(program.current_regimen).concept_names.tagged(["short"]).map(&:name) : nil; result 
		end
	end
	
  def transfer_out_patient(params)
    
    patient_program = PatientProgram.find(params[:patient_program_id])
    

    
    #we don't want to have more than one open states - so we have to close the current active on before opening/creating a new one

    current_active_state = patient_program.patient_states.last
    current_active_state.end_date = params[:current_date].to_date


     # set current location via params if given
    Location.current_location = Location.find(params[:location]) if params[:location]

    patient_state = patient_program.patient_states.build( :state => params[:current_state], :start_date => params[:current_date])


    if patient_state.save
      #Close and save current_active_state if a new state has been created
      current_active_state.save

      if patient_state.program_workflow_state.concept.fullname.upcase == 'PATIENT TRANSFERRED OUT'
      
        encounter = Encounter.new(params[:encounter])
        encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
        c = encounter.save

        (params[:observations] || [] ).each do |observation|
          #for now i do this
          obs = {}
          obs[:concept_name] = observation[:concept_name] 
          obs[:value_coded_or_text] = observation[:value_coded_or_text] 
          obs[:encounter_id] = encounter.id
          obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
          obs[:person_id] ||= encounter.patient_id  
          Observation.create(obs)
        end

        observation = {} 
        observation[:concept_name] = 'TRANSFER OUT TO'
        observation[:encounter_id] = encounter.id
        observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
        observation[:person_id] ||= encounter.patient_id
        observation[:value_text] = Location.find(params[:transfer_out_location_id]).name rescue "UNKNOWN"
        Observation.create(observation)
      end

      date_completed = params[:current_date].to_date rescue Time.now()
      
      PatientProgram.update_all "date_completed = '#{date_completed.strftime('%Y-%m-%d %H:%M:%S')}'",
                                 "patient_program_id = #{patient_program.patient_program_id}"
    end
  end
  
  protected


	def formulation(patient,regimen_id)
		criteria = Regimen.criteria(PatientService.get_patient_attribute_value(patient, "current_weight")).all(:conditions => {:concept_id => regimen_id}, :include => :regimen_drug_orders)
		options = []
    criteria.map do | r | 
			r.regimen_drug_orders.map do | order |
				options << [order.drug.name , order.dose, order.frequency , order.units , r.id ]
			end
		end
		return options  
	end


end
