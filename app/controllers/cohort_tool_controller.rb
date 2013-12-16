class CohortToolController < GenericCohortToolController

	def case_findings
	
		@variables = Hash.new(0)
		@quarter = params[:quarter]
    @start_date,@end_date = Report.generate_cohort_date_range(@quarter)
    encounters = Encounter.find(:all, :conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?", EncounterType.find_by_name("tb registration").id, @start_date, @end_date])
    tbtype = ConceptName.find_by_name("TB classification").concept_id
    patienttype = ConceptName.find_by_name("TB patient category").concept_id
		@variables["count"] = encounters.length
 
    encounters.each do |enc|
    		
    		tbclass = Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ? ", enc.id,tbtype]).value_coded).fullname

    	recurrent = Concept.find(Observation.find(:last, :conditions => ["concept_id = ? ",ConceptName.find_by_name("Ever received TB treatment").concept_id]).value_coded).fullname == "Yes"
    	
    		patclass = Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ? ", enc.id,patienttype]).value_coded).fullname
    		age = PatientService.age(enc.patient.person)
    		
    		if ((age >= 0) && (age <= 4))
    			case enc.patient.person.gender
    				when ("M")
    					@variables["Males"] +=1
    					@variables["Under5Males"] +=1    		
    				when ("F")
    					@variables["Females"] +=1    		
    					@variables["Under5Females"] +=1
    			end
    			@variables[case_find_cat_sort(patclass,tbclass,age= "Under5",gender= enc.patient.person.gender,recurrent)] +=1
    		elsif((age >= 5) && (age <= 14))

		  		case enc.patient.person.gender
		  				when ("M")
		  					@variables["Males"] +=1    		
		  					@variables["Under15Males"] +=1    		
		  				when ("F")
		  					@variables["Females"] +=1  
		  					@variables["Under15Females"] +=1  		
		  			end
		  			@variables[case_find_cat_sort(patclass,tbclass,age= "Under15",gender= enc.patient.person.gender,recurrent)] +=1
    		elsif((age >= 15) && (age <= 24))
    		
					case enc.patient.person.gender
		  				when ("M")
		  					@variables["Males"] +=1    		
		  					@variables["Under25Males"] +=1
		  				when ("F")
		  					@variables["Females"] +=1    		
		  					@variables["Under25Females"] +=1
		  			end
		  			@variables[case_find_cat_sort(patclass,tbclass,age= "Under25",gender= enc.patient.person.gender,recurrent)] +=1    		
    		elsif((age >= 25) && (age <= 34))
    		
						case enc.patient.person.gender
		  				when ("M")
		  					@variables["Males"] +=1
		  					@variables["Under35Males"] +=1    		
		  				when ("F")
		  					@variables["Females"] +=1    		
		  					@variables["Under35Females"] +=1
		  			end
		  			@variables[case_find_cat_sort(patclass,tbclass,age= "Under35",gender= enc.patient.person.gender,recurrent)] +=1    		
    		elsif((age >= 35) && (age <= 44))
    		
						case enc.patient.person.gender
		  				when ("M")
		  					@variables["Males"] +=1
		  					@variables["Under45Males"] +=1    		
		  				when ("F")
		  					@variables["Females"] +=1    		
		  					@variables["Under45Females"] +=1
		  			end
		  			@variables[case_find_cat_sort(patclass,tbclass,age= "Under45",gender= enc.patient.person.gender,recurrent)] +=1    		
    		elsif((age >= 45) && (age <= 54))

						case enc.patient.person.gender
		  				when ("M")
		  					@variables["Males"] +=1
		  					@variables["Under55Males"] +=1    		
		  				when ("F")
		  					@variables["Females"] +=1    		
		  					@variables["Under55Females"] +=1
		  			end
    			@variables[case_find_cat_sort(patclass,tbclass,age= "Under55",gender= enc.patient.person.gender,recurrent)] +=1    		
    		elsif((age >= 55) && (age <= 64))
					case enc.patient.person.gender
    				when ("M")
    					@variables["Males"] +=1    		
    					@variables["Under65Males"] +=1
    				when ("F")
    					@variables["Females"] +=1    		
    					@variables["Under65Females"] +=1
    			end
    			@variables[case_find_cat_sort(patclass,tbclass,age= "Under65",gender= enc.patient.person.gender,recurrent)] +=1    		
    		else
	    		case enc.patient.person.gender
    				when ("M")
    					@variables["Males"] +=1
    					@variables["Over64Males"] +=1    		
    				when ("F")
    					@variables["Females"] +=1    		
    					@variables["Over64Females"] +=1
    			end
    			@variables[case_find_cat_sort(patclass,tbclass,age= "Over64",gender= enc.patient.person.gender,recurrent)] +=1
    		end
    		
    end
    cats = ["Under5","Under15","Under25","Under35","Under45","Under55","Under65","Over64"]
    
    cats.each do |total|
    	@variables["MalesNew"] += @variables[total.to_s+"MPulnew"]
    	@variables["FemalesNew"] +=@variables[total.to_s+"FPulnew"]
    	@variables["FemaleOth"] += @variables[total.to_s+"Foth"]
    	@variables["MaleOth"] += @variables[total.to_s+"Moth"]
    	@variables["FemaleXP"] += @variables[total.to_s+"FXP"]
    	@variables["MaleXP"] += @variables[total.to_s+"MXP"]
    	@variables["MalesRel"] += @variables[total.to_s+"MPulrel"]
    	@variables["FemalesRel"] +=@variables[total.to_s+"FPulrel"]
    	@variables["MalesF"] += @variables[total.to_s+"MPulF"]
    	@variables["FemalesF"] +=@variables[total.to_s+"FPulF"]
    	@variables["MalesEP"] += @variables[total.to_s+"MEP"]
    	@variables["FemalesEP"] +=@variables[total.to_s+"FEP"]
    	@variables["MalesDef"] += @variables[total.to_s+"MPuldef"]
    	@variables["FemalesDef"] +=@variables[total.to_s+"FPuldef"]
    end
		render :layout => "report"
		
	end

  def pre_art
     session[:pre_art] = {}
     @logo = CoreService.get_global_property_value('logo').to_s
     @quarter = params[:quarter]
     start_date,end_date = Report.generate_cohort_date_range(@quarter)
     #raise CohortTool.new(start_date, end_date).to_yaml
     program = Program.find_by_name('HIV PROGRAM').id
     regimen_ids = CohortTool.patient_ids_with_regimens(end_date, program).join(",")

     #raise regimen_ids.to_yaml
     #raise CohortTool.defaulted_patients(end_date, regimen_ids).to_yaml
     session[:pre_art]["outcomes"] = {}
     
     session[:pre_art]["total_reg"], session[:pre_art]["earliest_start_date"] = CohortTool.total_on_pre_art(Date.today, regimen_ids)
     #raise session[:pre_art]["earliest_start_date"].to_yaml
     session[:pre_art]["registered"] = CohortTool.registered(start_date, end_date, regimen_ids)

     session[:pre_art]["patients_enrolled_first_time"] = CohortTool.patients_initiated_on_pre_art_first_time(session[:pre_art]["registered"].join(','), end_date, start_date) rescue []
     session[:pre_art]["patients_enrolled_first_time_ever"] = CohortTool.patients_initiated_on_pre_art_first_time(session[:pre_art]["total_reg"].join(','), end_date) rescue []

     session[:pre_art]["patients_reinrolled"] = CohortTool.patients_reinitiated_on_pre_art(session[:pre_art]["registered"].join(','), end_date, start_date) rescue []
     session[:pre_art]["patients_reinrolled_ever"] = CohortTool.patients_reinitiated_on_pre_art(session[:pre_art]["total_reg"].join(','), end_date) rescue []

     #raise session[:pre_art]["patients_reinrolled_ever"].to_yaml

     session[:pre_art]["patients_transferred_in"] = CohortTool.patients_transferred_in(session[:pre_art]["registered"].join(','), end_date, start_date) rescue []
     session[:pre_art]["patients_transferred_in_ever"] = CohortTool.patients_transferred_in(session[:pre_art]["total_reg"].join(','), end_date) rescue []


    #Cumulative section
     session[:pre_art]["male_total"] = CohortTool.male_total(session[:pre_art]["total_reg"])
     session[:pre_art]["pregnant_female_total"] = CohortTool.pregnant_women(regimen_ids, end_date)

     session[:pre_art]["pregnant_female"] = CohortTool.pregnant_women(regimen_ids, end_date, start_date) rescue []

    session[:pre_art]["non_pregnant_female"] = CohortTool.female_non_pregnant((session[:pre_art]["registered"] - session[:pre_art]["pregnant_female"]))
     session[:pre_art]["non_pregnant_female_total"] = CohortTool.female_non_pregnant((session[:pre_art]["total_reg"] - session[:pre_art]["pregnant_female_total"]))
     
     session[:pre_art]["less_2_months_infants"] = CohortTool.infants_less_than_2_months(session[:pre_art]["total_reg"])
     session[:pre_art]["infants_between_2_and_24_months"] = CohortTool.infants_between_2_and_24_months(session[:pre_art]["total_reg"])
     session[:pre_art]["infants_between_24months_and_14_years"] = CohortTool.infants_between_24months_and_14_years(session[:pre_art]["total_reg"])
     session[:pre_art]["adults"] = CohortTool.adults(session[:pre_art]["total_reg"])

     session[:pre_art]["confirmed_on_pre_art"] = CohortTool.confirmed_on_pre_art(Date.today, start_date, regimen_ids) rescue []
     session[:pre_art]["exposed_on_pre_art"] = CohortTool.exposed_on_pre_art

     #Current quater section
      session[:pre_art]["male"] = CohortTool.male_total(session[:pre_art]["registered"])
      
     
      session[:pre_art]["less_2_months_infants_quater"] = CohortTool.infants_less_than_2_months(session[:pre_art]["registered"])
      session[:pre_art]["infants_between_2_and_24_months_quater"] = CohortTool.infants_between_2_and_24_months(session[:pre_art]["registered"])
      session[:pre_art]["infants_between_24months_and_14_years_quater"] = CohortTool.infants_between_24months_and_14_years(session[:pre_art]["registered"])
      session[:pre_art]["adults_quater"] = CohortTool.adults(session[:pre_art]["registered"])

      session[:pre_art]["confirmed_on_pre_art_quater"] = CohortTool.confirmed_on_pre_art(end_date, start_date, regimen_ids) rescue []
      session[:pre_art]["exposed_on_pre_art_quater"] = CohortTool.exposed_on_pre_art(end_date, start_date)


      #raise CohortTool.outcomes_total('On antiretrovirals', end_date).to_yaml

      session[:pre_art]["defaulted"] = []
      (CohortTool.defaulted_patients(end_date, regimen_ids) || []).each do |patient|
                  if session[:pre_art]["total_reg"].include?(patient)
                       session[:pre_art]["defaulted"] << patient
                       session[:pre_art]["outcomes"][patient.to_s] = "DEFAULTED"
                   end
               end
      
      session[:pre_art]["alive_on_pre_art"] = []
      (CohortTool.confirmed_on_pre_art(end_date, nil, regimen_ids) rescue []).each do |patient|
                  if ! session[:pre_art]["defaulted"].include?(patient) and session[:pre_art]["total_reg"].include?(patient)
                       session[:pre_art]["alive_on_pre_art"] << patient
                       session[:pre_art]["outcomes"][patient.to_s] = "Pre-ART"
                  end
                end

      session[:pre_art]["tranferred_out"] = []
      transfer_outs = CohortTool.outcomes_total('PATIENT TRANSFERRED OUT', end_date, regimen_ids)
      #raise transfer_outs.to_yaml
      session[:pre_art]["earliest_start_date"] << transfer_outs[1] rescue nil
      (transfer_outs[0] || []).each do |patient|
                  
                       session[:pre_art]["tranferred_out"] << patient
                       session[:pre_art]["outcomes"][patient.to_s] = "TRANSFERRED OUT"
                  end
      session[:pre_art]["on_arvs"] = []
      on_arvs = CohortTool.outcomes_total('On antiretrovirals', end_date, nil, start_date)
      session[:pre_art]["earliest_start_date"] << on_arvs[1] rescue nil
      (on_arvs[0] || []).each do |patient|
                  if ! session[:pre_art]["defaulted"].include?(patient) #and session[:pre_art]["total_reg"].include?(patient)
                       session[:pre_art]["on_arvs"] << patient
                       session[:pre_art]["outcomes"][patient.to_s] = "On ARV's"
                     end
                  end
      
      session[:pre_art]["died"] = []
      dead = CohortTool.outcomes_total('PATIENT DIED', end_date, regimen_ids)
      #session[:pre_art]["earliest_start_date"] << dead[1] rescue nil
      (dead[0] || []).each do |patient|
                       session[:pre_art]["died"] << patient
                       session[:pre_art]["outcomes"][patient.to_s] = "PATIENT DIED"
                   
                  end

    render :layout => "cohort"
  end

	def case_findings2
	
		@quarter = params[:quarter]
    @start_date,@end_date = Report.generate_cohort_date_range(@quarter)
		@variables = Hash.new(0)		

		encounters = Encounter.find(:all, :conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?", EncounterType.find_by_name("tb registration").id, @start_date - 1.year, @end_date - 1.year])
		
		encounters.each do |enc|

			index = enc.patient.person.gender
			state = PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient_id, @start_date]).patient_states.last.program_workflow_state.concept.shortname
			
			case state.upcase
				when "REGIMEN FAILURE" || "TREATMENT FAILURE"
						index += "F"
				when "PATIENT DIED" || "DIED"
						index += "DI"
				when "CURRENTLY IN TREATMENT" || "ON TREATMENT"
						index += "NoNotif"
				when "PATIENT CURED"
						index += "C"
				when "PATIENT TRANSFERRED OUT"
						index += "TO"
				when "DEFAULTED" || "Z_DEPRECATED PATIENT DEFAULTED"
						index += "DF"
				when "TREATMENT COMPLETE"
						index += "RC"
			end

			temp = case_find_sort(enc.patient_id)
			@variables[temp[0]+index] +=1
			@variables[temp[1]+index] +=1

		end
	
		render :layout => "report"

	end

	def case_find_sort(id)
		 
		values = [" "," "]
				
   	tbclass = Concept.find(Observation.find(:last, :conditions => ["person_id = ? and concept_id = ? ", id,Concept.find_by_name("TB classification").concept_id]).value_coded).fullname
   		
   	patclass = Concept.find(Observation.find(:last, :conditions => ["person_id = ? and concept_id = ? ", id,Concept.find_by_name("TB patient category").concept_id	]).value_coded).fullname

			case tbclass

				when "Pulmonary tuberculosis"
					values[0] = "SMpos"
				when "Extrapulmonary tuberculosis (EPTB)"
					values[0] = "SMeptb"
				else
					values[0] = "SMneg"
			end
		
			case patclass

				when "Failed - TB"
					values[1] ="SMrtaf"
				when "Relapse MDR-TB patient"
					values[1] ="rel"
				when "Treatment after default MDR-TB patient"
					values[1] ="SMrtad"
				when "Other"
					values[1] = "SMrec"
			end

		return values

	end
	
	def case_find_cat_sort(patientclass,tbtype,age,gender, recc)

			if patientclass == "New patient"
				store = age.to_s+gender.to_s+"Pulnew"
			elsif patientclass == "Treatment after default MDR-TB patient" || patientclass == "Retreatment after default TB case"
				store = age.to_s+gender.to_s+"Puldef"
			elsif patientclass == "Failed - TB" || patientclass == "TB retreatment after failure case"
				store = age.to_s+gender.to_s+"PulF"
			elsif patientclass == "Relapse MDR-TB patient"
				store = age.to_s+gender.to_s+"Pulrel"
			else 
				if (recc == "Yes")
					store = age.to_s+gender.to_s+"oth"
				end
			end

			
			if tbtype == "Extrapulmonary tuberculosis (EPTB)"
					
					store = age.to_s+gender.to_s+"EP"

			elsif tbtype == "Pulmonary tuberculosis" 
			
					
			else
					
					store = age.to_s+gender.to_s+"XP"
					
			end
			
			return store
	end
  def select
    @cohort_quarters  = [""]
    @report_type      = params[:report_type]
    @header 	        = params[:report_type] rescue ""
    @page_destination = ("/" + params[:dashboard].gsub("_", "/")) rescue ""

    if @report_type == "in_arv_number_range"
      @arv_number_start = params[:arv_number_start]
      @arv_number_end   = params[:arv_number_end]
    end

    start_date  = PatientService.initial_encounter.encounter_datetime rescue Date.today

    end_date    = Date.today

    @cohort_quarters  += Report.generate_cohort_quarters(start_date, end_date)
  end

  def reports
    session[:list_of_patients] = nil

    if params[:report]
      case  params[:report_type]
			when "visits_by_day"
				redirect_to :action   => "visits_by_day",
					:name     => params[:report],
					:pat_name => "Visits by day",
					:quarter  => params[:report].gsub("_"," ")
        return

			when "non_eligible_patients_in_cohort"
				date = Report.generate_cohort_date_range(params[:report])

				redirect_to :action       => "non_eligible_patients_in_art",
					:controller   => "report",
					:start_date   => date.first.to_s,
					:end_date     => date.last.to_s,
					:id           => "start_reason_other",
					:report_type  => "non_eligible patients in: #{params[:report]}"
        return

			when "out_of_range_arv_number"
				redirect_to :action           => "out_of_range_arv_number",
					:arv_end_number   => params[:arv_end_number],
					:arv_start_number => params[:arv_start_number],
					:quarter          => params[:report].gsub("_"," "),
					:report_type      => params[:report_type]
        return

			when "data_consistency_check"
				redirect_to :action       => "data_consistency_check",
					:quarter      => params[:report],
					:report_type  => params[:report_type]
        return

			when "summary_of_records_that_were_updated"
				redirect_to :action   => "records_that_were_updated",
					:quarter  => params[:report].gsub("_"," ")
        return

			when "adherence_histogram_for_all_patients_in_the_quarter"
				redirect_to :action   => "adherence",
					:quarter  => params[:report].gsub("_"," ")
        return

			when "patients_with_adherence_greater_than_hundred"
				redirect_to :action  => "patients_with_adherence_greater_than_hundred",
					:quarter => params[:report].gsub("_"," ")
        return

			when "patients_with_multiple_start_reasons"
				redirect_to :action       => "patients_with_multiple_start_reasons",
					:quarter      => params[:report],
					:report_type  => params[:report_type]
        return

			when "dispensations_without_prescriptions"
				redirect_to :action       => "dispensations_without_prescriptions",
					:quarter      => params[:report],
					:report_type  => params[:report_type]
        return

			when "prescriptions_without_dispensations"
				redirect_to :action       => "prescriptions_without_dispensations",
					:quarter      => params[:report],
					:report_type  => params[:report_type]
        return

			when "drug_stock_report"
				start_date  = "#{params[:start_year]}-#{params[:start_month]}-#{params[:start_day]}"
				end_date    = "#{params[:end_year]}-#{params[:end_month]}-#{params[:end_day]}"

				if end_date.to_date < start_date.to_date
					redirect_to :controller   => "cohort_tool",
						:action       => "select",
						:report_type  =>"drug_stock_report" and return
				end rescue nil

				redirect_to :controller => "drug",
					:action     => "report",
					:start_date => start_date,
					:end_date   => end_date,
					:quarter    => params[:report].gsub("_"," ")
        return
      end
    end
  end

  def records_that_were_updated
    @quarter    = params[:quarter]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location = Location.current_health_center.name
    date_range  = Report.generate_cohort_date_range(@quarter)
    @start_date = date_range.first
    @end_date   = date_range.last

    @encounters = records_that_were_corrected(@quarter)

     render:layout =>"report"
  end

  def records_that_were_corrected(quarter)

    date        = Report.generate_cohort_date_range(quarter)
    start_date  = (date.first.to_s  + " 00:00:00")
    end_date    = (date.last.to_s   + " 23:59:59")

    voided_records = {}

    other_encounters = Encounter.find_by_sql("SELECT encounter.* FROM encounter
                        INNER JOIN obs ON encounter.encounter_id = obs.encounter_id
                        WHERE (encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}')
                        GROUP BY encounter.encounter_id
                        ORDER BY encounter.encounter_type, encounter.patient_id")

    drug_encounters = Encounter.find_by_sql("SELECT encounter.* FROM encounter
                        INNER JOIN orders ON encounter.encounter_id = orders.encounter_id
                        WHERE (encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}')
                        ORDER BY encounter.encounter_type")

    voided_encounters = []
    other_encounters.delete_if { |encounter| voided_encounters << encounter if (encounter.voided == 1)}

    voided_encounters.map do |encounter|
      patient           = Patient.find(encounter.patient_id) rescue nil
      if patient.nil?
        patient_details = {"patient_id" => encounter.patient_id,
                           "arv_number" => '',
                           "patient_name" => '',
                           "national_id" => ''
                         }
        arv_id = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
        national_id = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
        
        patient_details[:arv_number] = PatientIdentifier.find(:first, 
                                        :select => "identifier",
                                        :conditions  =>["patient_id = ? and identifier_type = ?", 
                                          encounter.patient_id, arv_id],
                                      :order => "date_created DESC" ).identifier rescue nil
        patient_details[:national_id] = PatientIdentifier.find(:first, 
                                        :select => "identifier",
                                        :conditions  =>["patient_id = ? and identifier_type = ?", 
                                          encounter.patient_id, national_id],
                                      :order => "date_created DESC" ).identifier rescue nil
        person = PersonName.find_by_sql("SELECT pn.* FROM person p INNER JOIN person_name pn ON pn.person_id = p.person_id WHERE p.person_id = #{encounter.patient_id}")
        patient_details[:patient_name] = person.first.given_name + ' ' + person.first.family_name rescue nil
        
      else
        patient_bean = PatientService.get_patient(patient.person)
      end

      new_encounter  = other_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
						e.patient_id      == encounter.patient_id &&
						e.encounter_type  == encounter. encounter_type)
        result
      end

      new_encounter = new_encounter.last

      next if new_encounter.nil?

      voided_observations = voided_observations(encounter)
      changed_to    = changed_to(new_encounter)
      changed_from  = changed_from(voided_observations) if ! voided_observations.nil? 

      if( voided_observations && !voided_observations.empty?)
				voided_records[encounter.id] = {
					"id"              => (patient.nil?) ? encounter.patient_id : patient.patient_id,
					"arv_number"      => (patient.nil?) ? patient_details[:arv_number] : patient_bean.arv_number,
					"name"            => (patient.nil?) ? patient_details[:patient_name] : patient_bean.name,
					"national_id"     => (patient.nil?) ? patient_details[:national_id] : patient_bean.national_id,
					"encounter_name"  => encounter.name,
					"voided_date"     => encounter.date_voided,
					"reason"          => encounter.void_reason,
					"change_from"     => changed_from,
					"change_to"       => changed_to
				}
      end
    end

    voided_treatments = []
    drug_encounters.delete_if { |encounter| voided_treatments << encounter if (encounter.voided == 1)}

    voided_treatments.each do |encounter|

      patient           = Patient.find(encounter.patient_id)
      patient_bean = PatientService.get_patient(patient.person)
      
      orders            = encounter.orders
      changed_from      = ''
      changed_to        = ''

			new_encounter  =  drug_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
						e.patient_id      == encounter.patient_id &&
						e.encounter_type  == encounter. encounter_type)
				result
			end

      new_encounter = new_encounter.last

      next if new_encounter.nil?
      changed_from  += "Treatment: #{voided_orders(new_encounter).to_s.gsub!(":", " =>")}</br>"
      changed_to    += "Treatment: #{encounter.to_s.gsub!(":", " =>") }</br>"

      if( orders && !orders.empty?)
        voided_records[encounter.id]= {
					"id"              => patient.patient_id,
					"arv_number"      => patient_bean.arv_number,
					"name"            => patient_bean.name,
					"national_id"     => patient_bean.national_id,
					"encounter_name"  => encounter.name,
					"voided_date"     => encounter.date_voided,
					"reason"          => encounter.void_reason,
					"change_from"     => changed_from,
					"change_to"       => changed_to
        }
      end

    end

    show_tabuler_format(voided_records)
  end

	def show_tabuler_format(records)

    patients = {}

    records.each do |key,value|

      sorted_values = sort(value)

      patients["#{key},#{value['id']}"] = sorted_values
    end

    patients
  end

  def sort(values)
    name              = ''
    patient_id        = ''
    arv_number        = ''
    national_id       = ''
    encounter_name    = ''
    voided_date       = ''
    reason            = ''
    obs_names         = ''
    changed_from_obs  = {}
    changed_to_obs    = {}
    changed_data      = {}

    values.each do |value|
      value_name =  value.first
      value_data =  value.last

      case value_name
			when "id"
				patient_id = value_data
			when "arv_number"
				arv_number = value_data
			when "name"
				name = value_data
			when "national_id"
				national_id = value_data
			when "encounter_name"
				encounter_name = value_data
			when "voided_date"
				voided_date = value_data
			when "reason"
				reason = value_data
			when "change_from"
				value_data.split("</br>").each do |obs|
					obs_name  = obs.split(':')[0].strip
					obs_value = obs.split(':')[1].strip rescue ''

					changed_from_obs[obs_name] = obs_value
				end unless value_data.blank?
			when "change_to"

				value_data.split("</br>").each do |obs|
					obs_name  = obs.split(':')[0].strip
					obs_value = obs.split(':')[1].strip rescue ''

					changed_to_obs[obs_name] = obs_value
				end unless value_data.blank?
      end
    end

    changed_from_obs.each do |a,b|
      changed_to_obs.each do |x,y|

        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_from_obs.delete(a)
          changed_to_obs.delete(x)
        end
      end
    end

    changed_to_obs.each do |a,b|
      changed_from_obs.each do |x,y|
        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_to_obs.delete(a)
          changed_from_obs.delete(x)
        end
      end
    end

    changed_data.each do |k,v|
      from  = v.split("to")[0].strip rescue ''
      to    = v.split("to")[1].strip rescue ''

      if obs_names.blank?
        obs_names = "#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      else
        obs_names += "</br>#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      end
    end

    results = {
			"id"              => patient_id,
			"arv_number"      => arv_number,
			"name"            => name,
			"national_id"     => national_id,
			"encounter_name"  => encounter_name,
			"voided_date"     => voided_date,
			"obs_name"        => obs_names,
			"reason"          => reason
		}

    results
  end

  def changed_from(observations)
    changed_obs = ''

    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
				when "value_coded"
					next if obs.value_coded.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_datetime"
					next if obs.value_datetime.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_numeric"
					next if obs.value_numeric.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_text"
					next if obs.value_text.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_modifier"
					next if obs.value_modifier.blank?
					changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end

  def changed_to(enc)
    encounter_type = enc.encounter_type

    encounter = Encounter.find(:first,
			:joins       => "INNER JOIN obs ON encounter.encounter_id=obs.encounter_id",
			:conditions  => ["encounter_type=? AND encounter.patient_id=? AND Date(encounter.encounter_datetime)=?",
				encounter_type,enc.patient_id, enc.encounter_datetime.to_date],
			:group       => "encounter.encounter_type",
			:order       => "encounter.encounter_datetime DESC")

    observations = encounter.observations rescue nil
    return if observations.blank?

    changed_obs = ''
    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
				when "value_coded"
					next if obs.value_coded.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_datetime"
					next if obs.value_datetime.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_numeric"
					next if obs.value_numeric.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_text"
					next if obs.value_text.blank?
					changed_obs += "#{obs.to_s}</br>"
				when "value_modifier"
					next if obs.value_modifier.blank?
					changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end

  def visits_by_day
    @quarter    = params[:quarter]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location = Location.current_health_center.name
    date_range          = Report.generate_cohort_date_range(@quarter)
    @start_date         = date_range.first
    @end_date           = date_range.last
    visits              = get_visits_by_day(@start_date.beginning_of_day, @end_date.end_of_day)
    @patients           = visiting_patients_by_day(visits)
    @visits_by_day      = visits_by_week(visits)
    @visits_by_week_day = visits_by_week_day(visits)

    render :layout => "report"
  end

  def visits_by_week(visits)

    visits_by_week = visits.inject({}) do |week, visit|

      day       = visit.encounter_datetime.strftime("%a")
      beginning = visit.encounter_datetime.beginning_of_week.to_date

      # add a new week
      week[beginning] = {day => []} if week[beginning].nil?

      #add a new visit to the week
      (week[beginning][day].nil?) ? week[beginning][day] = [visit] : week[beginning][day].push(visit)

      week
    end

    return visits_by_week
  end

  def visits_by_week_day(visits)
    week_day_visits = {}
    visits          = visits_by_week(visits)
    weeks           = visits.keys.sort
    week_days       = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    week_days.each_with_index do |day, index|
      weeks.map do  |week|
        visits_number = 0
        visit_date    = week.to_date.strftime("%d-%b-%Y")
        js_date       = week.to_time.to_i * 1000
        this_day      = visits[week][day]


        unless this_day.nil?
          visits_number = this_day.count
          visit_date    = this_day.first.encounter_datetime.to_date.strftime("%d-%b-%Y")
          js_date       = this_day.first.encounter_datetime.to_time.to_i * 1000
        else
					this_day      = (week.to_date + index.days)
					visit_date    = this_day.strftime("%d-%b-%Y")
					js_date       = this_day.to_time.to_i * 1000
        end

        (week_day_visits[day].nil?) ? week_day_visits[day] = [[js_date, visits_number, visit_date]] : week_day_visits[day].push([js_date, visits_number, visit_date])
      end
    end
    week_day_visits
  end

  def visiting_patients_by_day(visits)

    patients = visits.inject({}) do |patient, visit|

      visit_date = visit.encounter_datetime.strftime("%d-%b-%Y")

			patient_bean = PatientService.get_patient(visit.patient.person)
	  
      # get a patient of a given visit
      new_patient   = { :patient_id   => (visit.patient.patient_id || ""),
				:arv_number   => (patient_bean.arv_number || ""),
				:name         => (patient_bean.name || ""),
				:national_id  => (patient_bean.national_id || ""),
				:gender       => (patient_bean.sex || ""),
				:age          => (patient_bean.age || ""),
				:birthdate    => (patient_bean.birth_date || ""),
				:phone_number => (PatientService.phone_numbers(visit.patient) || ""),
				:start_date   => (visit.patient.encounters.last.encounter_datetime.strftime("%d-%b-%Y") || "")
      }

      #add a patient to the day
      (patient[visit_date].nil?) ? patient[visit_date] = [new_patient] : patient[visit_date].push(new_patient)

      patient
    end

    patients
  end

  def get_visits_by_day(start_date,end_date)
    required_encounters = ["ART ADHERENCE", "ART_FOLLOWUP",   "HIV CLINIC REGISTRATION",
			"HIV CLINIC CONSULTATION",     "HIV RECEPTION",  "HIV STAGING",   "VITALS"]

    required_encounters_ids = required_encounters.inject([]) do |encounters_ids, encounter_type|
      encounters_ids << EncounterType.find_by_name(encounter_type).id rescue nil
      encounters_ids
    end

    required_encounters_ids.sort!

    Encounter.find(:all,
      :joins      => ["INNER JOIN obs     ON obs.encounter_id    = encounter.encounter_id",
				"INNER JOIN patient ON patient.patient_id  = encounter.patient_id"],
      :conditions => ["obs.voided = 0 AND encounter_type IN (?) AND encounter_datetime >=? AND encounter_datetime <=?",required_encounters_ids,start_date,end_date],
      :group      => "encounter.patient_id,DATE(encounter_datetime)",
      :order      => "encounter.encounter_datetime ASC")
  end

  def prescriptions_without_dispensations
		include_url_params_for_back_button
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    @current_location = Location.current_health_center.name
		date_range  = Report.generate_cohort_date_range(params[:quarter])
		start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
		end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
		@report     = report_prescriptions_without_dispensations_data(start_date , end_date)

		render :layout => 'report'
  end
  
  def  dispensations_without_prescriptions
		include_url_params_for_back_button
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    @current_location = Location.current_health_center.name
		date_range  = Report.generate_cohort_date_range(params[:quarter])
		start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
		end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
		@report     = report_dispensations_without_prescriptions_data(start_date , end_date)

		render :layout => 'report'
  end
  
  def  patients_with_multiple_start_reasons
		include_url_params_for_back_button
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    @current_location = Location.current_health_center.name
		date_range  = Report.generate_cohort_date_range(params[:quarter])
		start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
		end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
		@report     = report_patients_with_multiple_start_reasons(start_date , end_date)

		render :layout => 'report'
  end
  
  def out_of_range_arv_number

		include_url_params_for_back_button
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    @current_location = Location.current_health_center.name
		date_range        = Report.generate_cohort_date_range(params[:quarter])
		start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
		end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
		arv_number_range  = [params[:arv_start_number].to_s.gsub(/[^0-9]/,'').to_i, params[:arv_end_number].to_s.gsub(/[^0-9]/,'').to_i]

		@report = report_out_of_range_arv_numbers(arv_number_range, start_date, end_date)

		render :layout => 'report'
  end
  
  def data_consistency_check
		include_url_params_for_back_button
		date_range  = Report.generate_cohort_date_range(params[:quarter])
		start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
		end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    @location_name = Location.current_health_center.name
		@dead_patients_with_visits       = report_dead_with_visits(start_date, end_date)
		@males_allegedly_pregnant        = report_males_allegedly_pregnant(start_date, end_date)
		@move_from_second_line_to_first =  report_patients_who_moved_from_second_to_first_line_drugs(start_date, end_date)
		@patients_with_wrong_start_dates = report_with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)
		session[:data_consistency_check] = { :dead_patients_with_visits => @dead_patients_with_visits,
			:males_allegedly_pregnant  => @males_allegedly_pregnant,
			:patients_with_wrong_start_dates => @patients_with_wrong_start_dates,
			:move_from_second_line_to_first =>  @move_from_second_line_to_first
		}
		@checks = [['Dead patients with visits', @dead_patients_with_visits.length],
			['Male patients with a pregnant observation', @males_allegedly_pregnant.length],
			['Patients who moved from 2nd to 1st line drugs', @move_from_second_line_to_first.length],
			['patients with start dates > first receive drug dates', @patients_with_wrong_start_dates.length]]
		render :layout => 'report'
  end
  
  def list
    @report = []
    include_url_params_for_back_button
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    @current_location = Location.current_health_center.name
    case params[:check_type]
		when 'Dead patients with visits' then
			@report  =  session[:data_consistency_check][:dead_patients_with_visits]
		when 'Patients who moved from 2nd to 1st line drugs'then
			@report =  session[:data_consistency_check][:move_from_second_line_to_first]
		when 'Male patients with a pregnant observation' then
			@report =  session[:data_consistency_check][:males_allegedly_pregnant]
		when 'patients with start dates > first receive drug dates' then
			@report =  session[:data_consistency_check][:patients_with_wrong_start_dates]
		else

    end

    render :layout => 'report'
  end

	def list_debbuger_details

		
		@logo = CoreService.get_global_property_value('logo').to_s
		@quarter = params[:quarter]
  	@report_url = "/cohort_tool/cohort?quarter=#{@quarter}"
		@report = []
		reported_range = params[:value].to_s
		@sort = CoreService.get_global_property_value('sort')
		@export_data = session["export.cohort.data"].to_s.downcase
		patients = params[:attribute].to_s
		session[:field] = params[:field] if session[:field].nil?
		
		if session[:field] == "children"
			data =  session[:children][reported_range][patients]
		elsif session[:field] == "women"
			data =  session[:women][reported_range][patients]
		elsif session[:field] == "general"
			data =  session[:views]["#{reported_range}"]["#{patients}"]
		end

		#records_per_page = CoreService.get_global_property_value('records_per_page') rescue 15
		#@current_page = []

		#if !data.nil?
			#@current_page = data.paginate(:page => params[:page], :per_page => 100)
		#end

		data.each do |patient_id|
			patient = Patient.find(patient_id)
			@report << PatientService.get_debugger_details(patient.person)
			set_outcomes_and_start_reason(patient_id) #find start reason and outcome for patient
		end
		@report.sort! { |a,b| a.splitted_arv_number.to_i <=> b.splitted_arv_number.to_i }
			
		render :layout => 'patient_list'
	end
	
  def list_patients_details
    #raise session[:cohort].to_yaml
		@logo = CoreService.get_global_property_value('logo').to_s
    @report = []
    @quarter = params[:quarter]
  	@report_url = "/cohort_tool/cohort?quarter=#{@quarter}"
		@sort = CoreService.get_global_property_value('sort')
		sort_value = CoreService.get_global_property_value("debugger_sorting_attribute") rescue "arv_number"
    @export_data = session["export.cohort.data"].to_s.downcase
		
    data_type = "to_s"
    data_type = "to_i" if ["age", "person_id", "patient_id"].include?(sort_value)
    
		key = session[:cohort].keys.sort.select { |k|
			k.humanize.upcase == params[:field].humanize.upcase
		}.first.to_s rescue nil

    if key.blank?
       key = session[:pre_art].keys.sort.select { |k|
          k.humanize.upcase == params[:field].humanize.upcase
        }.first.to_s rescue ""
        data = session[:pre_art][key] rescue []
      (data || []).each do |patient_id|
        patient = Patient.find(patient_id) rescue Patient.find(patient_id.person_id)  rescue Patient.find(patient_id.patient_id)
        @report << PatientService.get_debugger_details(patient.person)

        #find start reason
         # set_outcomes_and_start_reason(patient_id)
		end
    else

		session[:cohort]["sorted"]={} if session[:cohort]["sorted"].blank?
		if params[:field] == "patients_with_7+_doses_missed_at_their_last_visit" 
			#raise session[:cohort]["#{params[:field].humanize}"].to_yaml
			data = []
			session[:cohort]["#{params[:field].humanize}"].each do |patient_id|
				data << patient_id
			end
			session[:cohort]["sorted"]["#{params[:field].humanize}"] = true

		elsif params[:field] == "patients_with_0_-_6_doses_missed_at_their_last_visit"
			data = []
			session[:cohort]["#{params[:field].humanize}"].each do |patient_id|
				data <<  patient_id
			end
			session[:cohort]["sorted"]["#{params[:field].humanize}"] = true
		elsif params[:field] == "total_patients_with_side_effects"
			data = []
			session[:cohort]["#{params[:field].humanize}"].map do |patient_id|
				data <<  patient_id.patient_id
			end
			session[:cohort]["sorted"]["#{params[:field].humanize}"] = true
		elsif params[:field] == "regimens"
			type=params[:type].humanize.upcase
			
			(session[:cohort][key][type] || []).sort! do |a,b|
				PatientService.get_patient(Person.find(a)).send(sort_value).send(data_type) <=>
					PatientService.get_patient(Person.find(b)).send(sort_value).send(data_type)
			end if session[:cohort]["sorted"]["#{type}"].blank?
																		
			data=session[:cohort][key][type]
			session[:cohort]["sorted"]["#{type}"] = true

		else
			session[:cohort][key].sort! do |a,b|
				PatientService.get_patient(Person.find(a)).send(sort_value).send(data_type) <=>
					PatientService.get_patient(Person.find(b)).send(sort_value).send(data_type)
			end if session[:cohort]["sorted"]["#{key}"].blank?
			
			data=session[:cohort][key] 
			session[:cohort]["sorted"]["#{key}"] = true
		end
       (data || []).each do |patient_id|
          patient = Patient.find(patient_id)
          @report << PatientService.get_debugger_details(patient.person)

          #find start reason
          set_outcomes_and_start_reason(patient_id)
       end
    end


		@report.sort! { |a,b| a.splitted_arv_number.to_i <=> b.splitted_arv_number.to_i }

		render :layout => 'patient_list'
  end

	def set_outcomes_and_start_reason(patient_id)
		#Same code as it was in the list_patient_details method
		#Re-used so as to get the outcomes and start reasons in the survival analysis debugger
		#
		#find start reason
		session[:cohort]["start_reason"] = {} if session[:cohort]["start_reason"].blank?

		if !session[:cohort]["start_reason"][patient_id.to_s].blank?
			#we already have the start reason  for the patient therefore no need for searching

		elsif session[:cohort]['Total Confirmed HIV infection in infants (PCR)'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'Confirmed HIV infection in infants (PCR)'

		elsif session[:cohort]['Total Presumed severe HIV disease in infants'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'Presumed severe HIV disease in infants'

		elsif session[:cohort]['Total WHO stage 1 or 2, CD4 below threshold'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'WHO stage 1 or 2, CD4 below threshold'

		elsif session[:cohort]['Total WHO stage 2, total lymphocytes'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'WHO stage 2, total lymphocytes'

		elsif session[:cohort]['Total Patient breastfeeding'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'Patient breastfeeding'

		elsif session[:cohort]['Total Patient pregnant'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'Patient pregnant'

		elsif session[:cohort]['Total Unknown reason'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'Unknown reason'

		elsif session[:cohort]['Total WHO stage 4'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'WHO stage 4'

		elsif session[:cohort]['Total HIV infected'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'HIV infected'

		elsif session[:cohort]['Total WHO stage 3'].include?(patient_id)
			session[:cohort]["start_reason"][patient_id.to_s]	= 'WHO stage 3'
		end

		#find patient outcome
		session[:cohort]["outcomes"] = {} if session[:cohort]["outcomes"].blank?
    session[:cohort]["Stopped taking ARVs"] = {} if session[:cohort]["Stopped taking ARVs"].blank?
    
		if !session[:cohort]["outcomes"][patient_id.to_s].blank?
			#we already have the outcome for the patient therefore no need for searching

		elsif session[:cohort]['Defaulted'].include?(patient_id)
			session[:cohort]["outcomes"][patient_id.to_s]	= 'Defaulted'

		elsif session[:cohort]['Total alive and on ART'].include?(patient_id)
			session[:cohort]["outcomes"][patient_id.to_s]	= 'Alive and on ART'

		elsif session[:cohort]['Died total'].include?(patient_id)
			session[:cohort]["outcomes"][patient_id.to_s]	= 'Patient died'

		elsif session[:cohort]['Stopped taking ARVs'].include?(patient_id)
			session[:cohort]["outcomes"][patient_id.to_s]	= 'Stopped taking ARVs'

		elsif session[:cohort]['Unknown outcomes'].include?(patient_id)
			session[:cohort]["outcomes"][patient_id.to_s]	= 'Unknown outcome'

		elsif session[:cohort]['Transferred out'].include?(patient_id)
			session[:cohort]["outcomes"][patient_id.to_s]	= 'Transferred out'
		end
	end

  def include_url_params_for_back_button
		@report_quarter = params[:quarter]
		@report_type = params[:report_type]
  end
  
  def select_cohort_date
  end

  def cohort
    if params[:quarter] == 'Select date range'
      redirect_to :action => 'select_cohort_date' and return
    end
    session[:pre_art] = []
		@logo = CoreService.get_global_property_value('logo').to_s

    if params[:date] and not params[:date]['start'].blank? and not params[:date]['end'].blank?
      @quarter = params[:date]['start'] + " to " + params[:date]['end']
      start_date = params[:date]['start'].to_date
      end_date = params[:date]['end'].to_date
    end if not params[:date].blank?

    if start_date.blank? and end_date.blank?
      @quarter = params[:quarter]
      start_date,end_date = Report.generate_cohort_date_range(@quarter)
    end

    cohort = Cohort.new(start_date, end_date)
   	logger.info("cohort")
    #raise request.env["HTTP_CONNECTION"].to_yaml
		if session[:cohort].blank?
		  @cohort = cohort.report(logger)
		  session[:cohort]=@cohort
		else
			@cohort = session[:cohort]
		end
		session[:views]=nil; session[:chidren]; session[:nil]
    render :layout => 'report'
  end

  def missed_appointment
    @logo = CoreService.get_global_property_value('logo').to_s
    @quarter = params[:quarter]
    @start_date, @end_date = Report.generate_cohort_date_range(@quarter)

    @missed_patients = Cohort.miss_appointment(@start_date, @end_date)
    
    render :layout => 'report'
  end
  
	def survival_analysis
		session[:field] = nil
		session[:cohort]["outcomes"] = {} if session[:cohort]["outcomes"].blank?
    @quarter = params[:quarter]
		@logo = params[:logo]
    if @quarter.match(/to/i)
      start_date,end_date = @quarter.split('to')
      start_date = start_date.to_date
      end_date = end_date.to_date
    else
		  start_date,end_date = Report.generate_cohort_date_range(@quarter)
    end
    cohort = Cohort.new(start_date, end_date)

		@survival_analysis, session[:views] = SurvivalAnalysis.report(cohort, session[:cohort])

		render :layout => 'cohort'
	end

  def list_incomplete_details
    @logo = CoreService.get_global_property_value('logo').to_s
    @data = session[:specific][params[:date].to_date]
    @report = {}
    session[:incomplete][params[:date].to_date].each do |patient_id|
          patient = Patient.find(patient_id)
          @report[patient_id] =  PatientService.get_debugger_details(patient.person)
    end
    render :layout => 'patient_list'
  end
  
  def incomplete_visits
    @logo = CoreService.get_global_property_value('logo').to_s
    @start_date = params[:start_date].to_date
    @end_date = params[:start_date].to_date
    @incomplete = {}
    session[:specific] = {}
    session[:incomplete] = {}

    encounter_date =  params[:start_date].to_date
    # Need to improve the code for performance
    #while encounter_date <= params[:start_date].to_date
    session[:specific][encounter_date] = {}
    @incomplete[encounter_date] = []
    session[:specific][encounter_date]["reception"] = []
    session[:specific][encounter_date]["vitals"] = []
    session[:specific][encounter_date]["registration"] = []
    session[:specific][encounter_date]["consultation"] = []
    session[:specific][encounter_date]["staging"] = []
    session[:specific][encounter_date]["adherence"] = []
    session[:specific][encounter_date]["treatment"] = []
    session[:specific][encounter_date]["dispensing"] = []
    session[:specific][encounter_date]["appointment"] = []

    Encounter.find_by_sql("SELECT DISTINCT patient_id FROM encounter_type et
      INNER JOIN encounter e ON et.encounter_type_id = e.encounter_type
      WHERE encounter_datetime BETWEEN '#{encounter_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      AND '#{encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')}' 
      AND et.name IN ('UPDATE HIV STATUS','HIV CLINIC REGISTRATION','HIV STAGING',
      'HIV CLINIC CONSULTATION','ART ADHERENCE','DISPENSING')").each{|patient|

      registration = check_encounter(patient.patient_id, encounter_date, "HIV CLINIC REGISTRATION")# rescue []
      reception = check_encounter(patient.patient_id, encounter_date, "HIV RECEPTION")#  rescue []
      vitals = "Non Applicable"
      unless reception.blank?
        vitals = check_encounter(patient.patient_id, encounter_date, "VITALS") if reception.to_s.match(/Patient present for consultation:  Yes/i)
      else
         @incomplete[encounter_date] << patient.patient_id
         vitals = check_encounter(patient.patient_id, encounter_date, "VITALS")# rescue []
         session[:specific][encounter_date]["reception"] << patient.patient_id
      end
      if registration.to_s.match(/Not Done/i)
         #raise registration.to_yaml if registration.length < 2
         @incomplete[encounter_date] << patient.patient_id #if registration.to_s.match(/Not Done/i)
         session[:specific][encounter_date]["registration"]  << patient.patient_id #if registration.to_s.match(/Not Done/i)
         staging = check_encounter(patient.patient_id, encounter_date, "HIV STAGING")# rescue []
         @incomplete[encounter_date] << patient.patient_id if  staging.blank?
         session[:specific][encounter_date]["staging"] << patient.patient_id if staging.blank?
     elsif registration.blank?
         adherence = check_encounter(patient.patient_id, encounter_date, "ART ADHERENCE") #rescue []
         @incomplete[encounter_date] << patient.patient_id if  adherence.blank?
         session[:specific][encounter_date]["adherence"] << patient.patient_id if adherence.blank?
      else
         staging = check_encounter(patient.patient_id, encounter_date, "HIV STAGING")# rescue []
         @incomplete[encounter_date] << patient.patient_id if  staging.blank?
         session[:specific][encounter_date]["staging"] << patient.patient_id if staging.blank?
      end
       session[:specific][encounter_date]["vitals"] << patient.patient_id if vitals.blank?

       @incomplete[encounter_date] << patient.patient_id if vitals.blank?

       consultation = check_encounter(patient.patient_id, encounter_date, "HIV CLINIC CONSULTATION") #rescue []
       @incomplete[encounter_date] << patient.patient_id if  consultation.blank?
       session[:specific][encounter_date]["consultation"] << patient.patient_id if consultation.blank?
       unless consultation.blank?
         
         if consultation.to_s.match(/Prescribe drugs:  Yes/i)
          
           treatment = check_encounter(patient.patient_id, encounter_date, "TREATMENT") #rescue []
           dispensing = check_encounter(patient.patient_id, encounter_date, "DISPENSING") #rescue []
           appointment = check_encounter(patient.patient_id, encounter_date, "APPOINTMENT") #rescue []

           @incomplete[encounter_date] << patient.patient_id if treatment.blank?
           @incomplete[encounter_date] << patient.patient_id if dispensing.blank?
           @incomplete[encounter_date] << patient.patient_id if appointment.blank?
           session[:specific][encounter_date]["appointment"] << patient.patient_id if appointment.blank?
           session[:specific][encounter_date]["dispensing"] << patient.patient_id if dispensing.blank?
           session[:specific][encounter_date]["treatment"] << patient.patient_id if treatment.blank?
            
        end

       end
     }
     
     session[:incomplete][encounter_date] = @incomplete[encounter_date].uniq
     #encounter_date += 1.days

     #end
    redirect_to "/cohort_tool/list_incomplete_details?date=#{encounter_date}"
    #render :layout => 'patient_list'
  end
  
	def children_survival
		session[:field] = nil
    @quarter = params[:quarter]

		@logo = params[:logo]
    if @quarter.match(/to/i)
      start_date,end_date = @quarter.split('to')
      start_date = start_date.to_date
      end_date = end_date.to_date
    else
		  start_date,end_date = Report.generate_cohort_date_range(@quarter)
    end
    cohort = Cohort.new(start_date, end_date)
		@children_survival_analysis, session[:children] = SurvivalAnalysis.childern_survival_analysis(cohort, session[:cohort])
		render :layout => 'cohort'
	end

	def women_survival
		session[:field] = nil
    @quarter = params[:quarter]
		@logo = params[:logo]
    if @quarter.match(/to/i)
      start_date,end_date = @quarter.split('to')
      start_date = start_date.to_date
      end_date = end_date.to_date
    else
		  start_date,end_date = Report.generate_cohort_date_range(@quarter)
    end
    cohort = Cohort.new(start_date, end_date)
   	logger.info("cohort")
   	@women_survival_analysis, session[:women] = SurvivalAnalysis.pregnant_and_breast_feeding(cohort, session[:cohort])
		
		render :layout => 'cohort'
	end

  def cohort_menu
  end

  def adherence
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location = Location.current_health_center.name
    adherences = get_adherence(params[:quarter])
    @adherences = adherences
    @quarter = params[:quarter]
    type = "patients_with_adherence_greater_than_hundred"
    @type = type
    @report_type = "Adherence Histogram for all patients"
    #@adherence_summary = "&nbsp;&nbsp;<button onclick='adhSummary();'>Summary</button>" unless adherences.blank?
    #@adherence_summary+="<input class='test_name' type=\"button\" onmousedown=\"document.location='/cohort_tool/reports?report=#{@quarter}&report_type=#{type}';\" value=\"Over 100% Adherence\"/>"  unless adherences.blank?
    @adherence_summary_hash = Hash.new(0)
    adherences.each{|adherence,value|
      adh_value = value.to_i
      current_adh = adherence.to_i
      if current_adh <= 94
        @adherence_summary_hash["0 - 94"]+= adh_value
      elsif current_adh >= 95 and current_adh <= 100
        @adherence_summary_hash["95 - 100"]+= adh_value
      else current_adh > 100
        @adherence_summary_hash["> 100"]+= adh_value
      end
    }
    @adherence_summary_hash['missing'] = CohortTool.missing_adherence(@quarter).length rescue 0
    @adherence_summary_hash.values.each{|n|@adherence_summary_hash["total"]+=n}

    data = ""
    adherences.each{|x,y|data+="#{x}:#{y}:"}
    @id = data[0..-2] || ''

    @results = @id
    @results = @results.split(':').enum_slice(2).map
    @results = @results.each {|result| result[0] = result[0]}.sort_by{|result| result[0]}
    @results.each{|result| @graph_max = result[1].to_f if result[1].to_f > (@graph_max || 0)}
    @graph_max ||= 0
    render :layout => "report"
  end

  def patients_with_adherence_greater_than_hundred
    @logo = CoreService.get_global_property_value('logo').to_s
		min_range = params[:min_range]
		max_range = params[:max_range]
		missing_adherence = false
		missing_adherence = true if params[:show_missing_adherence] == "yes"
		session[:list_of_patients] = nil

		@patients = adherence_over_hundred(params[:quarter],min_range,max_range,missing_adherence)
		#Cohort.regimens_with_patient_ids(@first_registration_date)
		@quarter = params[:quarter] + ": (#{@patients.length})" rescue  params[:quarter]
		if missing_adherence
			@report_type = "Patient(s) with missing adherence"
      #render :layout => 'patient_list' and return
		elsif max_range.blank? and min_range.blank?
			@report_type = "Patient(s) with adherence greater than 100%"
		else
			@report_type = "Patient(s) with adherence starting from  #{min_range}% to #{max_range}%"
		end
		render :layout => 'report'
		return
  end

  def report_patients_with_multiple_start_reasons(start_date , end_date)

    art_eligibility_id = ConceptName.find_by_name('REASON FOR ART ELIGIBILITY').concept_id    
    patients = Observation.find_by_sql(
			["SELECT person_id, concept_id, date_created, obs_datetime, value_coded_name_id
                 FROM obs
                 WHERE (SELECT COUNT(*)
                        FROM obs observation
                        WHERE   observation.concept_id = ?
                                AND observation.person_id = obs.person_id) > 1                               
                                AND date_created >= ? AND date_created <= ?
                                AND obs.concept_id = ?
                                AND obs.voided = 0 
               	 ORDER BY person_id ASC", art_eligibility_id, start_date, end_date, art_eligibility_id])

    patients_data = []

    patients.each do |reason|
      patient = Patient.find(reason[:person_id])
      patient_bean = PatientService.get_patient(patient.person)
      patients_data << {'person_id' => patient.id,
				'arv_number' => patient_bean.arv_number,
				'national_id' => patient_bean.national_id,
				'date_created' => reason[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
				'start_reason' => (ConceptName.find(reason[:value_coded_name_id]).name rescue '')
			}
    end
		patients_data
  end

  def voided_observations(encounter)
    voided_obs = Observation.find_by_sql("SELECT * FROM obs WHERE obs.encounter_id = #{encounter.encounter_id} AND obs.voided = 1")
    (!voided_obs.empty?) ? voided_obs : nil
  end

  def voided_orders(new_encounter)
    voided_orders = Order.find_by_sql("SELECT * FROM orders WHERE orders.encounter_id = #{new_encounter.encounter_id} AND orders.voided = 1")
    (!voided_orders.empty?) ? voided_orders : nil
  end

  def report_out_of_range_arv_numbers(arv_number_range, start_date , end_date)
    arv_number_id = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    arv_start_number = arv_number_range.first.to_s.gsub(/[^0-9]/,'').to_i
    arv_end_number = arv_number_range.last.to_s.gsub(/[^0-9]/,'').to_i
    
    arv_number_suffix = PatientIdentifier.find_by_identifier_type(arv_number_id).identifier.gsub(/[0-9]/, '')

    out_of_range_arv_numbers  = PatientIdentifier.find_by_sql(["SELECT patient_id, identifier, date_created FROM patient_identifier
                                   WHERE identifier_type = ? AND (REPLACE(identifier, '#{arv_number_suffix}', '')+0) >= ?
                                   AND (REPLACE(identifier, '#{arv_number_suffix}', '')+0) <= ?
                                   AND voided = 0
                                   AND (NOT EXISTS(SELECT * FROM patient_identifier
                                   WHERE identifier_type = ? AND date_created >= ? AND date_created <= ?))
                                   ORDER BY (REPLACE(identifier, '#{arv_number_suffix}', '')+0) ASC",
				arv_number_id,  arv_start_number,  arv_end_number, arv_number_id, start_date, end_date])

    out_of_range_arv_numbers_data = []
    out_of_range_arv_numbers.each do |arv_num_data|
      patient     = Patient.find(arv_num_data[:patient_id].to_i)
      patient_bean = PatientService.get_patient(patient.person)

      out_of_range_arv_numbers_data <<{'person_id' => patient.id,
				'arv_number' => patient_bean.arv_number,
				'name' => patient_bean.name,
				'national_id' => patient_bean.national_id,
				'gender' => patient_bean.sex,
				'age' => patient_bean.age,
				'birthdate' => patient_bean.birth_date,
				'date_created' => arv_num_data[:date_created].strftime("%Y-%m-%d %H:%M:%S")
			}
    end
    out_of_range_arv_numbers_data
  end
  
  def report_dispensations_without_prescriptions_data(start_date , end_date)
    pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id

    missed_prescriptions_data = Observation.find(:all, :select =>  "person_id, value_drug, date_created",
			:conditions =>["order_id IS NULL
                                                AND date_created >= ? AND date_created <= ? AND
                                                    concept_id = ? AND voided = 0" ,start_date , end_date, pills_dispensed_id])
    dispensations_without_prescriptions = []

    missed_prescriptions_data.each do |dispensation|
			patient = Patient.find(dispensation[:person_id])
			patient_bean = PatientService.get_patient(patient.person)
			drug_name    = Drug.find(dispensation[:value_drug]).name

			dispensations_without_prescriptions << { 'person_id' => patient.id,
				'arv_number' => patient_bean.arv_number,
				'national_id' => patient_bean.national_id,
				'date_created' => dispensation[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
				'drug_name' => drug_name
			}
    end

    dispensations_without_prescriptions
  end
  
  def report_prescriptions_without_dispensations_data(start_date , end_date)
    pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id

    missed_dispensations_data = Observation.find_by_sql(["SELECT order_id, patient_id, date_created from orders 
              WHERE NOT EXISTS (SELECT * FROM obs
               WHERE orders.order_id = obs.order_id AND obs.concept_id = ?)
                AND date_created >= ? AND date_created <= ? AND orders.voided = 0", pills_dispensed_id, start_date , end_date ])

    prescriptions_without_dispensations = []

    missed_dispensations_data.each do |prescription|
			patient      = Patient.find(prescription[:patient_id])
			drug_id      = DrugOrder.find(prescription[:order_id]).drug_inventory_id
			drug_name    = Drug.find(drug_id).name

			prescriptions_without_dispensations << {'person_id' => patient.id,
				'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number'),
				'national_id' => PatientService.get_national_id(patient),
				'date_created' => prescription[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
				'drug_name' => drug_name
			}
    end
    prescriptions_without_dispensations
  end

  def report_dead_with_visits(start_date, end_date)
    patient_died_concept    = ConceptName.find_by_name('PATIENT DIED').concept_id

    all_dead_patients_with_visits = "SELECT * 
    FROM (SELECT observation.person_id AS patient_id, DATE(p.death_date) AS date_of_death, DATE(observation.date_created) AS date_started
          FROM person p right join obs observation ON p.person_id = observation.person_id
          WHERE p.dead = 1 AND DATE(p.death_date) < DATE(observation.date_created) AND observation.voided = 0
          ORDER BY observation.date_created ASC) AS dead_patients_visits
    WHERE DATE(date_of_death) >= DATE('#{start_date}') AND DATE(date_of_death) <= DATE('#{end_date}')
    GROUP BY patient_id"
    patients = Patient.find_by_sql([all_dead_patients_with_visits])
    
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:patient_id].to_i)
      patient_bean = PatientService.get_patient(person)
      patients_data <<{ 'person_id' => person.id,
				'arv_number' => patient_bean.arv_number,
				'name' => patient_bean.name,
				'national_id' => patient_bean.national_id,
				'gender' => patient_bean.sex,
				'age' => patient_bean.age,
				'birthdate' => patient_bean.birth_date,
				'phone' => PatientService.phone_numbers(person),
				'date_created' => patient_data_row[:date_started]
			}
    end
    patients_data
  end
  
  def report_males_allegedly_pregnant(start_date, end_date)
    pregnant_patient_concept_id = ConceptName.find_by_name('IS PATIENT PREGNANT?').concept_id
    patients = PatientIdentifier.find_by_sql(["
                                   SELECT person.person_id,obs.obs_datetime
                                       FROM obs INNER JOIN person ON obs.person_id = person.person_id
                                           WHERE person.gender = 'M' AND
                                           obs.concept_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ? AND obs.voided = 0",
        pregnant_patient_concept_id, '2008-12-23 00:00:00', end_date])

		patients_data  = []
		patients.each do |patient_data_row|
			person = Person.find(patient_data_row[:person_id].to_i)
		  patient_bean = PatientService.get_patient(person)
			patients_data <<{ 'person_id' => person.id,
				'arv_number' => patient_bean.arv_number,
				'name' => patient_bean.name,
				'national_id' => patient_bean.national_id,
				'gender' => patient_bean.sex,
				'age' => patient_bean.age,
				'birthdate' => patient_bean.birth_date,
				'phone' => PatientService.phone_numbers(person),
				'date_created' => patient_data_row[:obs_datetime]
			}
		end
		patients_data
  end

  def report_patients_who_moved_from_second_to_first_line_drugs(start_date, end_date)
  
    first_line_regimen = "('D4T+3TC+NVP', 'd4T 3TC + d4T 3TC NVP')"
    second_line_regimen = "('AZT+3TC+NVP', 'D4T+3TC+EFV', 'AZT+3TC+EFV', 'TDF+3TC+EFV', 'TDF+3TC+NVP', 'TDF/3TC+LPV/r', 'AZT+3TC+LPV/R', 'ABC/3TC+LPV/r')"
    
    patients_who_moved_from_nd_to_st_line_drugs = "SELECT * FROM (
        SELECT patient_on_second_line_drugs.* , DATE(patient_on_first_line_drugs.date_created) AS date_started FROM (
        SELECT person_id, date_created
        FROM obs
        WHERE value_drug IN (
        SELECT drug_id 
        FROM drug 
        WHERE concept_id IN (SELECT concept_id FROM concept_name 
        WHERE name IN #{second_line_regimen}))
        ) AS patient_on_second_line_drugs inner join

        (SELECT person_id, date_created
        FROM obs
        WHERE value_drug IN (
        SELECT drug_id 
        FROM drug 
        WHERE concept_id IN (SELECT concept_id FROM concept_name 
        WHERE name IN #{first_line_regimen}))
        ) AS patient_on_first_line_drugs
        ON patient_on_first_line_drugs.person_id = patient_on_second_line_drugs.person_id
        WHERE DATE(patient_on_first_line_drugs.date_created) > DATE(patient_on_second_line_drugs.date_created) AND
              DATE(patient_on_first_line_drugs.date_created) >= DATE('#{start_date}') AND DATE(patient_on_first_line_drugs.date_created) <= DATE('#{end_date}')
        ORDER BY patient_on_first_line_drugs.date_created ASC) AS patients
        GROUP BY person_id"

    patients = Patient.find_by_sql([patients_who_moved_from_nd_to_st_line_drugs])
    
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:person_id].to_i)
      patient_bean = PatientService.get_patient(person)
      patients_data <<{ 'person_id' => person.id,
				'arv_number' => patient_bean.arv_number,
				'name' => patient_bean.name,
				'national_id' => patient_bean.national_id,
				'gender' => patient_bean.sex,
				'age' => patient_bean.age,
				'birthdate' => patient_bean.birth_date,
				'phone' => PatientService.phone_numbers(person),
				'date_created' => patient_data_row[:date_started]
			}
    end
    patients_data
  end
  
  def report_with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)

    arv_drugs_concepts      = MedicationService.arv_drugs.inject([]) {|result, drug| result << drug.concept_id}
    on_arv_concept_id       = ConceptName.find_by_name('ON ANTIRETROVIRALS').concept_id
    hvi_program_id          = Program.find_by_name('HIV PROGRAM').program_id
    national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
    arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id

    patients_on_antiretrovirals_sql = "
         (SELECT p.patient_id, s.date_created as Date_Started_ARV
          FROM patient_program p INNER JOIN patient_state s
          ON  p.patient_program_id = s.patient_program_id
          WHERE s.state IN (SELECT program_workflow_state_id
                            FROM program_workflow_state g
                            WHERE g.concept_id = #{on_arv_concept_id})
                            AND p.program_id = #{hvi_program_id}
         ) patients_on_antiretrovirals"

    antiretrovirals_obs_sql = "
         (SELECT * FROM obs
          WHERE  value_drug IN (SELECT drug_id FROM drug
          WHERE concept_id IN ( #{arv_drugs_concepts.join(', ')} ) )
         ) antiretrovirals_obs"

    drug_start_dates_less_than_program_enrollment_dates_sql= "
      SELECT * FROM (
                  SELECT patients_on_antiretrovirals.patient_id, DATE(patients_on_antiretrovirals.date_started_ARV) AS date_started_ARV,
                         antiretrovirals_obs.obs_datetime, antiretrovirals_obs.value_drug
                  FROM #{patients_on_antiretrovirals_sql}, #{antiretrovirals_obs_sql}
                  WHERE patients_on_antiretrovirals.Date_Started_ARV > antiretrovirals_obs.obs_datetime
                        AND patients_on_antiretrovirals.patient_id = antiretrovirals_obs.person_id
                        AND patients_on_antiretrovirals.Date_Started_ARV >='#{start_date}' AND patients_on_antiretrovirals.Date_Started_ARV <= '#{end_date}'
                  ORDER BY patients_on_antiretrovirals.date_started_ARV ASC) AS patient_select
      GROUP BY patient_id"


    patients       = Patient.find_by_sql(drug_start_dates_less_than_program_enrollment_dates_sql)
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:patient_id])
			patient_bean = PatientService.get_patient(person)
      patients_data <<{ 'person_id' => person.id,
				'arv_number' => patient_bean.arv_number,
				'name' => patient_bean.name,
				'national_id' => patient_bean.national_id,
				'gender' => patient_bean.sex,
				'age' => patient_bean.age,
				'birthdate' => patient_bean.birth_date,
				'phone' => PatientService.phone_numbers(person),
				'date_created' => patient_data_row[:date_started_ARV]
			}
    end
    patients_data
  end
  
  def get_adherence(quarter="Q1 2009")
		date = Report.generate_cohort_date_range(quarter)

		start_date  = date.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
		end_date    = date.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
		adherences  = Hash.new(0)
		adherence_concept_id = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id

		adherence_sql_statement= " SELECT worse_adherence_dif, pat_ad.person_id as patient_id, pat_ad.value_text AS adherence_rate_worse
                            FROM (SELECT ABS(100 - Abs(value_text)) as worse_adherence_dif, obs_id, person_id, concept_id, encounter_id, order_id, obs_datetime, location_id, value_text
                                  FROM obs q
                                  WHERE concept_id = #{adherence_concept_id} AND order_id IS NOT NULL
                                  ORDER BY q.obs_datetime DESC, worse_adherence_dif DESC, person_id ASC)pat_ad
                            WHERE pat_ad.obs_datetime >= '#{start_date}' AND pat_ad.obs_datetime<= '#{end_date}'
                            GROUP BY patient_id "

		adherence_rates = Observation.find_by_sql(adherence_sql_statement)
		adherence_rates.each{|adherence|

			rate = adherence.adherence_rate_worse.to_i

			if rate >= 91 and rate <= 94
				cal_adherence = 94
			elsif  rate >= 95 and rate <= 100
				cal_adherence = 100
			else
				cal_adherence = rate + (5- rate%5)%5
			end
			adherences[cal_adherence]+=1
		}
		adherences
  end

  def adherence_over_hundred(quarter="Q1 2009",min_range = nil,max_range=nil,missing_adherence=false)
    date_range                 = Report.generate_cohort_date_range(quarter)
    start_date                 = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    end_date                   = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    adherence_range_filter     = " (adherence_rate_worse >= #{min_range} AND adherence_rate_worse <= #{max_range}) "
    adherence_concept_id       = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
    brought_drug_concept_id    = ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id

    patients = {}

    if (min_range.blank? or max_range.blank?) and !missing_adherence
			adherence_range_filter = " (adherence_rate_worse > 100) "
    elsif missing_adherence

			adherence_range_filter = " (adherence_rate_worse IS NULL) "

    end

    patients_with_adherences =  " (SELECT   oders.start_date, obs_inner_order.obs_datetime, obs_inner_order.adherence_rate AS adherence_rate,
                                        obs_inner_order.id, obs_inner_order.patient_id, obs_inner_order.drug_inventory_id AS drug_id,
                                        ROUND(DATEDIFF(obs_inner_order.obs_datetime, oders.start_date)* obs_inner_order.equivalent_daily_dose, 0) AS expected_remaining,
                                        obs_inner_order.quantity AS quantity, obs_inner_order.encounter_id, obs_inner_order.order_id
                               FROM (SELECT latest_adherence.obs_datetime, latest_adherence.adherence_rate, latest_adherence.id, latest_adherence.patient_id, latest_adherence.order_id, drugOrder.drug_inventory_id, drugOrder.equivalent_daily_dose, drugOrder.quantity, latest_adherence.encounter_id
                                    FROM (SELECT all_adherences.obs_datetime, all_adherences.value_text AS adherence_rate, all_adherences.obs_id as id, all_adherences.person_id as patient_id,all_adherences.order_id, all_adherences.encounter_id
                                          FROM (SELECT obs_id, person_id, concept_id, encounter_id, order_id, obs_datetime, location_id, value_text
                                                FROM obs Observations
                                                WHERE concept_id = #{adherence_concept_id}
                                                ORDER BY person_id ASC , Observations.obs_datetime DESC )all_adherences
                                          WHERE all_adherences.obs_datetime >= '#{start_date}' AND all_adherences.obs_datetime<= '#{end_date}'
                                          GROUP BY order_id, patient_id) latest_adherence
                                    INNER JOIN
                                          drug_order drugOrder
                                    On    drugOrder.order_id = latest_adherence.order_id) obs_inner_order
                               INNER JOIN
                                    orders oders
                               On     oders.order_id = obs_inner_order.order_id) patients_with_adherence  "

		worse_adherence_per_patient =" (SELECT worse_adherence_dif, pat_ad.person_id as patient_id, pat_ad.value_text AS adherence_rate_worse
                                FROM (SELECT ABS(100 - Abs(value_text)) as worse_adherence_dif, obs_id, person_id, concept_id, encounter_id, order_id, obs_datetime, location_id, value_text
                                      FROM obs q
                                      WHERE concept_id = #{adherence_concept_id} AND order_id IS NOT NULL
                                      ORDER BY q.obs_datetime DESC, worse_adherence_dif DESC, person_id ASC)pat_ad
                                WHERE pat_ad.obs_datetime >= '#{start_date}' AND pat_ad.obs_datetime<= '#{end_date}'
                                GROUP BY patient_id ) worse_adherence_per_patient   "

		patient_adherences_sql =  " SELECT *
                                 FROM   #{patients_with_adherences} INNER JOIN #{worse_adherence_per_patient}
                                 ON patients_with_adherence.patient_id = worse_adherence_per_patient.patient_id
                                 WHERE  #{adherence_range_filter} "

		rates = Observation.find_by_sql(patient_adherences_sql)

		patients_rates = []
		rates.each{|rate|
			patients_rates << rate
		}
		adherence_rates = patients_rates

    arv_number_id = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    adherence_rates.each{|rate|

      patient    = Patient.find(rate.patient_id)
      person     = patient.person
      patient_bean = PatientService.get_patient(person)
      drug       = Drug.find(rate.drug_id)
      pill_count = Observation.find(:first, :conditions => "order_id = #{rate.order_id} AND encounter_id = #{rate.encounter_id} AND concept_id = #{brought_drug_concept_id} ").value_numeric rescue ""
      if !patients[patient.patient_id] then

				patients[patient.patient_id]={"id" =>patient.id,
					"arv_number" => patient_bean.arv_number,
					"name" => patient_bean.name,
					"national_id" => patient_bean.national_id,
					"visit_date" =>rate.obs_datetime,
					"gender" =>patient_bean.sex,
					"age" => PatientService.patient_age_at_initiation(patient, rate.start_date.to_date),
					"birthdate" => patient_bean.birth_date,
					"pill_count" => pill_count.to_i.to_s,
					"adherence" => rate. adherence_rate_worse,
					"start_date" => rate.start_date.to_date,
					"expected_count" =>rate.expected_remaining,
					"drug" => drug.name}
			elsif  patients[patient.patient_id] then

				patients[patient.patient_id]["age"].to_i < PatientService.patient_age_at_initiation(patient, rate.start_date.to_date).to_i ? patients[patient.patient_id]["age"] = PatientService.patient_age_at_initiation(patient, rate.start_date.to_date).to_s : ""

				patients[patient.patient_id]["drug"] = patients[patient.patient_id]["drug"].to_s + "<br>#{drug.name}"

				patients[patient.patient_id]["pill_count"] << "<br>#{pill_count.to_i.to_s}"

				patients[patient.patient_id]["expected_count"] << "<br>#{rate.expected_remaining.to_i.to_s}"

				patients[patient.patient_id]["start_date"].to_date > rate.start_date.to_date ?
          patients[patient.patient_id]["start_date"] = rate.start_date.to_date : ""

			end
    }

    patients.sort { |a,b| a[1]['adherence'].to_i <=> b[1]['adherence'].to_i }
  end
  
	def report_duration
			@report_name = params[:report_name]
	end  
	
	def lab_register
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]

    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date.strftime('%d %B %Y')
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date.strftime('%d %B %Y')


		render :layout => "report"
	end
	
	def tb_register
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]

		@data= []
		@total = Hash.new(0)
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
		encounters = Encounter.find(:all, :conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?", EncounterType.find_by_name("tb registration").id, @start_date, @end_date])
    
    encounters.each do |enc|
    
    	person = Hash.new("")
    	person["reg_date"] = enc.encounter_datetime.to_date.strftime('%d/%b/%Y')
    	person["sex"] = enc.patient.person.gender
    	if (enc.patient.person.gender == "M")
    		@total["Males"] +=1
    	else
    		@total["Females"] +=1
    	end
    	person["age"] = PatientService.age(enc.patient.person)
    	person["address"] = enc.patient.person.addresses.first.city_village
    	person["person_id"] = enc.patient.id
    	person["name"] = enc.patient.person.names.first.given_name + ' ' + enc.patient.person.names.first.family_name rescue nil
    	person["cough_duration"] =Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ? ", enc.id,ConceptName.find_by_name("Duration of current cough").concept_id]).value_coded).shortname rescue nil
    	tbcat = Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ? ", enc.id,ConceptName.find_by_name("TB classification").concept_id]).value_coded).fullname
    	
    	if tbcat == "Pulmonary tuberculosis"
    		person["Category"] = "P"
    		@total["pulmonary"] +=1
    	else
	    	person["Category"] = "EP"
	    	@total["EP"] +=1
    	end
    	dot = Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ?",enc.id,ConceptName.find_by_name("Directly observed treatment option").concept_id]).value_coded).shortname
    	
    	case dot.upcase
    		when("GUARDIAN")
    			person["DOT"] = "Gua"
				when("HEALTH CENTER")
    			person["DOT"] = "HC"
   			when("HOSPITAL")
    			person["DOT"] = "Hosp"
   			when("COMMUNITY VOLUNTEER")
    			person["DOT"] = "Com. V" 
  			when("HEALTH CARE WORKER")
    			person["DOT"] = "HCW"
    	end
    	
    	ptype = Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ? ", enc.id,ConceptName.find_by_name("TB patient category").concept_id]).value_coded).fullname

    	case ptype.upcase
    		when ("NEW PATIENT")
    			person["pat_type"] = "New"
    			@total["new"] +=1
    		when ("FAILED - TB") 
    			person["pat_type"] = "Fail"
    			@total["fail"] +=1
    		when ("RELAPSE MDR-TB PATIENT")
    			person["pat_type"] = "Relap"
    			@total["relapse"] +=1
    		when ("TREATMENT AFTER DEFAULT MDR-TB PATIENT")
    			person["pat_type"] = "RAD"
    			@total["defualt"] +=1
    		else
    			person["pat_type"] = "Oth"
    			@total["other"] +=1
    	end
    	
    	person["tbnumber"] = PatientIdentifier.identifier(enc.patient.id, PatientIdentifierType.find_by_name("District TB Number").id).identifier rescue ""
    	@data << person
  	
    end

		render :layout => "report"
	end
	
	def register_specifics
		
		id = params[:id]
		@values = Hash.new("N/A")
		@values["name"] = params[:name]
		start = params[:start]
		end_date = params[:end]
		
		encounters = Encounter.find(:last, :conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and patient_id = ?", EncounterType.find_by_name("tb registration").id, start, end_date,id])
       	
    @values["hivstatus"] = PatientService.patient_hiv_status(encounters.patient)   
    	
			arvstart = PatientService.patient_art_start_date(id).to_date rescue nil

			if arvstart == nil
				@values["arvstatus"] = "C"
			elsif arvstart >  encounters.encounter_datetime.to_date
				@values["arvstatus"] = "A"
				@values["arvnumber"] = PatientService.get_patient_identifier(encounters.patient, 'ARV Number')
			else
				@values["arvstatus"] = "B"
				@values["arvnumber"] = PatientService.get_patient_identifier(encounters.patient, 'ARV Number')
		
			
			startedcpt = Observation.find(:first,:conditions => ["concept_id = ?",ConceptName.find_by_name("cpt given")])
				
				if (startedcpt != nil)
					@values["cpt"] = "Started"
				else
					@values["cpt"] = "Not Started"
				end
    end
    	
    	if ((@values["hivstatus"].upcase == "POSITIVE") || (@values["hivstatus"].upcase == "NEGATIVE"))
    		hivdate = PatientService.hiv_test_date(id)
    		if (hivdate != nil)
		  		if encounters.encounter_datetime.to_date < hivdate.to_date
		  			@values["hiv_test_date"] = "After"
		  		elsif encounters.encounter_datetime.to_date > hivdate.to_date
		  			@values["hiv_test_date"] = "Before"
		  		end
		  	end
    	end
    	
    culture_concepts = [ConceptName.find_by_name("Culture(1st) Results").concept_id,ConceptName.find_by_name("Culture-2 Results").concept_id]
    
		culture = Observation.find(:all, :conditions => ["person_id = ? AND obs_datetime >= ? AND obs_datetime <= ? AND concept_id in (?)", id, start,end_date, culture_concepts], :limit => 2).each { |ob|
			if Concept.find(ob.value_coded).fullname.to_s.include?"positive"
		  			@values["culture"] = "Positive"
		  			break
			else
						@values["culture"] = "Negative"
			end    			
		}

		
    	sputum_results = sputum_results_at_reg(encounters.encounter_datetime, encounters.patient.patient_id)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
    				@values["smearat1"] = "Positive"
					break
				elsif obs.value_coded == ConceptName.find_by_name("Negative").id
    				@values["smearat1"] = "Negative"
   			end}
   		
    	sputum_results2 = sputum_results_after_reg(encounters.encounter_datetime, encounters.patient.patient_id,60)
      sputum_results2.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
    				@values["smearat2"] = "Positive"
					break
				elsif obs.value_coded == ConceptName.find_by_name("Negative").id
    				@values["smearat2"] = "Negative"
   			end}

			date = encounters.encounter_datetime + 60.days
    	sputum_results5 = sputum_results_after_reg(date, encounters.patient.patient_id,150)
      sputum_results5.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
    				@values["smearat5"] = "Positive"
					break
				elsif obs.value_coded == ConceptName.find_by_name("Negative").id
    				@values["smearat5"] = "Negative"
   			end}

			date = encounters.encounter_datetime + 150.days
    	sputum_results6 = sputum_results_after_reg(date , encounters.patient.patient_id,180)
      sputum_results6.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
    				@values["smearat6"] = "Positive"
					break
				elsif obs.value_coded == ConceptName.find_by_name("Negative").id
    				@values["smearat6"] = "Negative"
   			end}

			date = encounters.encounter_datetime + 180.days
    	sputum_results8 = sputum_results_after_reg(date, encounters.patient.patient_id,210)
      sputum_results8.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
    				@values["smearat8"] = "Positive"
					break
				elsif obs.value_coded == ConceptName.find_by_name("Negative").id
    				@values["smearat8"] = "Negative"
   			end}

    				
			@values["outcome"] = Concept.find(Observation.find(:last, :conditions => ["concept_id = ?",ConceptName.find_by_name("TB treatment outcome").concept_id]).value_coded).fullname rescue nil
		render :layout => "menu"
	end

	def tb_register_summary
		temp = params[:start].to_s
		@start_date = params[:start].to_s.split(",")[0].to_date
		@end_date = params[:start].to_s.split(",")[1].to_date
		@total = Hash.new(0)
		encounters = Encounter.find(:all, :conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?", EncounterType.find_by_name("tb registration").id, @start_date, @end_date])
    
    encounters.each do |enc|
			@total["total"] +=1    
    	if (enc.patient.person.gender == "M")
    		@total["Males"] +=1
    	else
    		@total["Females"] +=1
    	end
    	tbcat = Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ? ", enc.id,ConceptName.find_by_name("TB classification").concept_id]).value_coded).fullname
    	
    	if tbcat == "Pulmonary tuberculosis"

    		@total["pulmonary"] +=1
    	else

    	end
    	
    	ptype = Concept.find(Observation.find(:last, :conditions => ["encounter_id = ? and concept_id = ? ", enc.id,ConceptName.find_by_name("TB patient category").concept_id]).value_coded).fullname

    	case ptype.upcase
    		when ("NEW PATIENT")

    			@total["new"] +=1
    		when ("FAILED - TB") 
	    	@total["EP"] +=1

    			@total["fail"] +=1
    		when ("RELAPSE MDR-TB PATIENT")

    			@total["relapse"] +=1
    		when ("TREATMENT AFTER DEFAULT MDR-TB PATIENT")

    			@total["defualt"] +=1
    		else

					@total["other"] +=1
    	end
    	
    	hivstatus = PatientService.patient_hiv_status(enc.patient)
    	
    	case hivstatus.upcase
    	
    	when ("POSITIVE")
    		@total["hivpos"] +=1
				arvstart = PatientService.patient_art_start_date(enc.patient.person.id).to_date.strftime(' %d- %b- %Y') rescue nil

				if arvstart == nil
					@total["statusC"] += 1
				elsif arvstart < enc.encounter_datetime.to_date.strftime(' %d- %b- %Y') 
					@total["statusA"] += 1
				elsif arvstart > enc.encounter_datetime.to_date.strftime(' %d- %b- %Y')
					@total["statusB"] += 1
				end
				startedcpt = Observation.find(:first,:conditions => ["concept_id = ? and person_id = ?",ConceptName.find_by_name("CPT Started").concept_id,enc.patient.person.id])
				
				if (startedcpt != nil)
					@total["cpt"] +=1
				end
    	when ("NEGATIVE")
    		@total["hivneg"] +=1

    	when ("UNKNOWN")
    		@total["hivunk"] +=1  	

    	end
    	
    	if ((hivstatus.upcase == "POSITIVE") || (hivstatus.upcase == "NEGATIVE"))
    		hivdate = PatientService.hiv_test_date(enc.patient.person.id)
    		if (hivdate != nil)
		  		if enc.encounter_datetime < hivdate
		  			@total["hivtestafta"] +=1
		  		elsif enc.encounter_datetime > hivdate
		  			@total["hivtestb4"] +=1
		  		end
		  	end
    	end
    	
    
    culture_concepts = [ConceptName.find_by_name("Culture(1st) Results").concept_id,ConceptName.find_by_name("Culture-2 Results").concept_id]
    
		culture = Observation.find(:all, :conditions => ["person_id = ? AND obs_datetime >= ? AND obs_datetime <= ? AND concept_id in (?)", enc.patient.patient_id, @start_date,@end_date, culture_concepts],:limit=>2)
		if (Concept.find(culture[0].value_coded).fullname.to_s.include?"positive") || (Concept.find(culture[1].value_coded).fullname.to_s.include?"positive")
				@total["culture"] +=1
		end rescue nil

    	smears = PatientService.sputum_results_by_date(enc.patient.person.id)
    	
    	sputum_results = sputum_results_at_reg(enc.encounter_datetime, enc.patient.patient_id)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
    				@total["initial+ve"] +=1
					break
   			end}
   		
    	sputum_results = sputum_results_after_reg(enc.encounter_datetime, enc.patient.patient_id,60)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Positive").id
    				@total["month2+ve"] +=1
					break
   			end}

			date = enc.encounter_datetime + 60.days
    	sputum_results = sputum_results_after_reg(date, enc.patient.patient_id,150)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Positive").id
    				@total["month5+ve"] +=1
					break
   			end}
		
			pattbstatus = PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient.patient_id, enc.encounter_datetime]).patient_states.last.program_workflow_state.concept.shortname
			
			case pattbstatus
				when ("Patient cured")
					@total["cured"] +=1
				when ("Patient died")
    		@total["died"] += 1
				when ("Regimen failure")
					@total["failure"] +=1
				when ("z_deprecated Patient defaulted")
					@total["Txdefault"] +=1
				when ("Patient transferred out")
					@total["transfer"] +=1
				when ("Treatment complete")
					@total["complete"] +=1
			end

    end
		render :layout => "summary"
	end
	
	def tb_register_summary_specifics
		start = params[:start]
		end_date = params[:end]
		category = params[:grp]
		@people = []
		
		case category
			when("by gender females")
				@title = "Female TB Patients"		
						encounters = Encounter.find(:all, 
						:joins => ["inner join person on encounter.patient_id = person.person_id "],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and person.gender = ?", EncounterType.find_by_name("tb registration").id, start, end_date, "F"])
						
			when("by gender males")				
				@title = "Male TB Patients"
						encounters = Encounter.find(:all, 
						:joins => ["inner join person on encounter.patient_id = person.person_id "],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and person.gender = ?", EncounterType.find_by_name("tb registration").id, start, end_date, "M"])
			
			when("by tbclass pul")
				@title = "Pulmonary TB Patients"
						encounters = Encounter.find(:all, 
						:joins => ["inner join obs on encounter.encounter_id = obs.encounter_id"],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and obs.concept_id = ? and obs.value_coded = ?", EncounterType.find_by_name("tb registration").id, start, end_date, ConceptName.find_by_name("TB classification").concept_id,ConceptName.find_by_name("Pulmonary tuberculosis").concept_id ])

			when("by tbclass EP")
				@title = "Extra Pulmonary TB Patients"
						encounters = Encounter.find(:all, 
						:joins => ["inner join obs on encounter.encounter_id = obs.encounter_id"],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and obs.concept_id = ? and obs.value_coded != ?", EncounterType.find_by_name("tb registration").id, start, end_date, ConceptName.find_by_name("TB classification").concept_id,ConceptName.find_by_name("Pulmonary tuberculosis").concept_id ])

			when("by patclass new")
				@title = "New TB Patients"
						encounters = Encounter.find(:all, 
						:joins => ["inner join obs on encounter.encounter_id = obs.encounter_id"],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and obs.concept_id = ? and obs.value_coded = ?", EncounterType.find_by_name("tb registration").id, start, end_date, ConceptName.find_by_name("TB patient category").concept_id, ConceptName.find_by_name("new patient").concept_id ])

	when("by patclass def")
		@title = "TB Patients being treated after defualt"
						encounters = Encounter.find(:all, 
						:joins => ["inner join obs on encounter.encounter_id = obs.encounter_id"],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and obs.concept_id = ? and obs.value_coded = ?", EncounterType.find_by_name("tb registration").id, start, end_date, ConceptName.find_by_name("TB patient category").concept_id, ConceptName.find_by_name("Treatment after default MDR-TB patient").concept_id ])

	when("by patclass fail")
		@title = "TB Patients being treated after failure"
						encounters = Encounter.find(:all, 
						:joins => ["inner join obs on encounter.encounter_id = obs.encounter_id"],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and obs.concept_id = ? and obs.value_coded = ?", EncounterType.find_by_name("tb registration").id, start, end_date, ConceptName.find_by_name("TB patient category").concept_id, ConceptName.find_by_name("Failed - TB").concept_id ])

	when("by patclass rel")
			@title = "TB Patients being treated after relapse"
						encounters = Encounter.find(:all, 
						:joins => ["inner join obs on encounter.encounter_id = obs.encounter_id"],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and obs.concept_id = ? and obs.value_coded = ?", EncounterType.find_by_name("tb registration").id, start, end_date, ConceptName.find_by_name("TB patient category").concept_id, ConceptName.find_by_name("Relapse MDR-TB patient").concept_id ])

	when("by patclass other")
				@title = "Other TB Patients "
		concepts = [ConceptName.find_by_name("new patient").concept_id,ConceptName.find_by_name("Treatment after default MDR-TB patient").concept_id,ConceptName.find_by_name("Failed - TB").concept_id,ConceptName.find_by_name("Relapse MDR-TB patient").concept_id]
		
						encounters = Encounter.find(:all, 
						:joins => ["inner join obs on encounter.encounter_id = obs.encounter_id"],
						:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ? and obs.concept_id = ? and obs.value_coded NOT in (?)", EncounterType.find_by_name("tb registration").id, start, end_date, ConceptName.find_by_name("TB patient category").concept_id, concepts ])
	
	when("hivneg")
		@title = "HIV Negative TB Patients"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if (PatientService.patient_hiv_status(enc.patient) == "Negative")
					encounters << enc
			end
		end

	when("hivpos")
		@title = "HIV Positive TB Patients"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if (PatientService.patient_hiv_status(enc.patient) == "Positive")
					encounters << enc
			end
		end

	when("hivunk")
		@title = "TB Patients with Unknown HIV Status"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if (PatientService.patient_hiv_status(enc.patient) == "Unknown")
					encounters << enc
			end
		end

	when("hivtestb4")
		@title = "Patients with HIV Status from Before TB Registration"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if (PatientService.hiv_test_date(enc.patient.person.id) < enc.encounter_datetime )
					encounters << enc
			end rescue nil
		end

	when("hivtestafta")
		@title = "Patients with HIV Status from After TB Registration"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if (PatientService.hiv_test_date(enc.patient.person.id) > enc.encounter_datetime )
					encounters << enc
			end rescue nil
		end
		
		when("artstartafta")
		@title = "Patients Who Started ART After TB Registration"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if (PatientService.patient_art_start_date(enc.patient.patient_id) > enc.encounter_datetime.to_date )
					encounters << enc
			end rescue nil
		end

		when("artstartb4")
		@title = "Patients Who Started ART Before TB Registration"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if (PatientService.patient_art_start_date(enc.patient.patient_id) < enc.encounter_datetime.to_date )
					encounters << enc
			end rescue nil
		end

		when("artnotstart")
		@title = "Patients Who Started ART Before TB Registration"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if ((PatientService.patient_hiv_status(enc.patient) == "Positive") && (PatientService.patient_art_start_date(enc.patient.patient_id) == nil))
					encounters << enc
			end rescue nil
		end
		
		when("startedcpt")

		@title = "Patients Who Started Have Started CPT"
		encounters = []	
		encounter = Encounter.find(:all, 
		:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",
		EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			if ((PatientService.patient_hiv_status(enc.patient) == "Positive") && (Observation.find(:first,:conditions => ["concept_id = ? and person_id = ?",ConceptName.find_by_name("CPT Started").concept_id, enc.patient.patient_id]) != nil))
					encounters << enc
			end rescue nil
		end
		
		when("dead")

		@title = "Patients Who Died While in Treatment"	
			encounters = []	
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			
			if( PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient.patient_id, enc.encounter_datetime]).patient_states.last.program_workflow_state.concept.shortname == "Patient died")
					encounters << enc
				end
			end rescue nil
		
		when("cured")
			@title = "Patients Who Were Cured"
			encounters = []	
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			
			if( PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient.patient_id, enc.encounter_datetime]).patient_states.last.program_workflow_state.concept.shortname == "Patient cured")
					encounters << enc
				end
			end rescue nil

		when("transfered")
			@title = "Patients Who Were Transferred Out"
			encounters = []	
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			
			if( PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient.patient_id, enc.encounter_datetime]).patient_states.last.program_workflow_state.concept.shortname == "Patient transferred out")
					encounters << enc
				end
			end rescue nil

		when("treatment complete")
			@title = "Patients Who Completed Treatment"
			encounters = []	
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
	
			if( PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient.patient_id, enc.encounter_datetime]).patient_states.last.program_workflow_state.concept.shortname == "Treatment complete")
						encounters << enc
				end
			end rescue nil

		when("defaulted")
			@title = "Patients Who Defualted Treatment"
			encounters = []	
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
	
			if( PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient.patient_id, enc.encounter_datetime]).patient_states.last.program_workflow_state.concept.shortname == "z_deprecated Patient defaulted")
						encounters << enc
				end
			end rescue nil

		when("failed")
			@title = "Patients With Failed Treatment"
			encounters = []	
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
	
			if( PatientProgram.find(:first, :conditions => ["program_id = ? and patient_id = ? and date_enrolled >=  ?", Program.find_by_name("TB Program").program_id, enc.patient.patient_id, enc.encounter_datetime]).patient_states.last.program_workflow_state.concept.shortname == "Regimen failure")
						encounters << enc
				end
			end rescue nil

		when ("Smear+ve1")
			@title = "Patients with Smear +ve Results at Initiation "
			encounters = []
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|

      sputum_results = sputum_results_at_reg(enc.encounter_datetime.to_date + 60 , enc.patient.patient_id)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
					encounters << enc
					break
   			end}
 			end
 			
		when ("Smear+ve2")
			@title = "Patients with Smear +ve Results at Month 2"
			encounters = []
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|

      sputum_results = sputum_results_after_reg(enc.encounter_datetime, enc.patient.patient_id,60)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
					encounters << enc
					break
   			end}
 			end

		when ("Smear+ve5")
			@title = "Patients with Smear +ve Results at Month 5"
			encounters = []
			encounter = Encounter.find(:all,:conditions => ["encounter_type = ? and encounter_datetime >= ? and encounter_datetime <= ?",	EncounterType.find_by_name("tb registration").id, start, end_date]).map do |enc|
			date = enc.encounter_datetime + 60.days
      sputum_results = sputum_results_after_reg(date, enc.patient.patient_id,150)
      sputum_results.each { |obs|
        if obs.value_coded != ConceptName.find_by_name("Negative").id
					encounters << enc
					break
   			end}
 			end


	end
	

	encounters.each do |enc|
		person = Hash.new("")
		person["birthdate"] = enc.patient.person.birthdate.strftime('%d %B %Y') rescue nil
		person["sex"] = enc.patient.person.gender
		person["reg_date"] = enc.encounter_datetime.to_date.strftime('%d %B %Y')
   	person["address"] = enc.patient.person.addresses.first.city_village
		person["name"] = enc.patient.person.names.first.given_name + ' ' + enc.patient.person.names.first.family_name rescue nil
  	person["tbnumber"] = PatientIdentifier.identifier(enc.patient.id, PatientIdentifierType.find_by_name("District TB Number").id).identifier
		@people << person
	end rescue nil


		render :layout => "report"	
	end	

  def sputum_results_at_reg(registration_date, patient_id)
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results",
      "AAFB(3rd) results"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)",
        sputum_concept_names]).map(&:concept_id)
    obs = Observation.find(:all,:conditions => ["person_id = ? AND value_coded != ? AND concept_id IN (?) AND obs_datetime <= ?",patient_id,ConceptName.find_by_name("Negative").id ,sputum_concept_ids, registration_date], :limit => 3)
  end

  def sputum_results_after_reg(registration_date, patient_id,add)
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results",
      "AAFB(3rd) results"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)",
        sputum_concept_names]).map(&:concept_id)
    obs = Observation.find(:all,:conditions => ["person_id = ? AND value_coded != ? AND concept_id IN (?) AND obs_datetime > ? AND obs_datetime <= ?",patient_id,ConceptName.find_by_name("Negative").id ,sputum_concept_ids, registration_date, registration_date + add.days], :limit => 3)
  end

  def check_encounter(patient_id, encounter_date, encounter)
    start_date = encounter_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')

    e = EncounterType.find_by_name(encounter).id
	  obs = Observation.find_by_sql("SELECT * FROM encounter e
      INNER JOIN obs o ON e.encounter_id = o.encounter_id WHERE o.voided = 0
      And e.encounter_type = #{e} AND o.person_id = #{patient_id}
      AND o.obs_datetime >= '#{start_date}' AND o.obs_datetime <= '#{end_date}'")
     
    if encounter == "HIV CLINIC REGISTRATION" and obs.blank?
      obs = Observation.find_by_sql("SELECT * FROM encounter e
      INNER JOIN obs o ON e.encounter_id = o.encounter_id
      WHERE o.voided = 0 AND e.encounter_type = #{e} AND o.person_id = #{patient_id}
      AND o.obs_datetime < '#{encounter_date.to_date.strftime('%Y-%m-%d 00:00:00')}' LIMIT 1")

      if !obs.blank?
        obs = []
      else
        obs = "Not Done"
      end

    end

    return obs
  end

end

