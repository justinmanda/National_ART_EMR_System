require 'yaml'

def initialize_variables
  # initializes the different variables required for the
  # flat table initalization process
  @source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))["production"]["database"]
  @started_at = Time.now.strftime("%Y-%m-%d-%H%M%S")
  @drug_list = get_drug_list
  @max_dispensing_enc_date = Encounter.find_by_sql("SELECT DATE(max(encounter_datetime)) AS adate
                                                    FROM encounter
                                                    WHERE encounter_type = 54").map(&:adate)
end

def pre_export_check
  #to contain checks before starting the process of initialization
end

def initiate_script
    puts "started at #{@started_at}"

    threads = []
    patients = Patient.find_by_sql("SELECT max(patient_id) as max_patient_id, count(*) record_count FROM #{@source_db}.earliest_start_date")
    record_count = patients.first.record_count
    max_patient_id = patients.first.max_patient_id
    thresholds = generate_thresholds(100, 338)

count = 0
  thresholds.each do |threshold| 
    threads << Thread.new(count) do |i|
      get_all_patients(threshold[0], threshold[1], count)
    end
      puts "#{count}"
      count += 1
  end
 
threads.each {|t| t.join}



=begin
    count = 0
    thresholds.each do |threshold|
	    count += 1
	    puts "#{threshold[0]}, #{threshold[1]}"
	    threads << Thread.new(count) do 
	        get_all_patients(threshold[0], threshold[1], count)
	    end
    end

    threads.each {|thread| thread.join}
=end
    puts "ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")}"
end

def generate_thresholds(records, patient_id)
   number_iterations = patient_id.to_i / records.to_i
   threshold = (patient_id.to_i + (number_iterations * 2)) / number_iterations.to_i
   threshold_array = []

   count = 0
   number_iterations.times do
	if count == 0
	   item = ["1", "#{threshold}"]
	else
	   last_item_index = threshold_array.length - 1
	   item = ["#{(threshold_array[last_item_index][1].to_i + 1)}","#{(threshold_array[last_item_index][1].to_i + threshold.to_i)}"]
	end
	threshold_array << item
	count += 1
   end
   
   return threshold_array
end

def get_all_patients(min, max, thread)
    puts "thread #{thread} started at #{Time.now.strftime("%Y-%m-%d-%H%M%S")} for ids #{min} to #{max}"
    min_patient_id = min
    max_patient_id = max
    #open output files for writing
    $temp_outfile_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
    $temp_outfile_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
    $temp_outfile_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    
    patient_list = Patient.find_by_sql("SELECT patient_id FROM #{@source_db}.earliest_start_date WHERE patient_id >= #{min_patient_id} AND patient_id <= #{max_patient_id}").map(&:patient_id)
    patient_list.each do |p|
      $temp_outfile_3 << "#{p}," 
	    sql_statements = get_patients_data(p)
    	$temp_outfile_1 << sql_statements[0]
    	$temp_outfile_2 << sql_statements[1]
    end
    
    #close output files 
    $temp_outfile_1.close
    $temp_outfile_2.close
    $temp_outfile_3.close
    
    puts "thread #{thread} ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")} for ids #{min} to #{max}"

end

def get_patients_data(patient_id)
 #flat_table1 will contain hiv_staging, hiv clinic regitsrtaion observations
 #and patient demographics

 hiv_clinic_registration = []; hiv_staging = []; demographics = []
 initial_flat_table1_string = "INSERT INTO flat_table1 "

 #get patient demographics
 demographics = get_patient_demographics(patient_id)

 #hiv_clinic_registration observations
 hiv_clinic_reg_obs = Encounter.find(:first,
                                     :conditions => ['patient_id = ?
                                                      AND encounter_type = 9',
                                                      patient_id],
                                     :order => 'encounter_datetime DESC').observations rescue nil
 if hiv_clinic_reg_obs
  hiv_clinic_registration = process_hiv_clinic_registration_encounter(hiv_clinic_reg_obs)
 end

 #hiv_staging observations
 hiv_staging_obs = Encounter.find(:first,
                                  :conditions => ['patient_id = ?
                                                   AND encounter_type = 52',
                                                   patient_id],
                                  :order => 'encounter_datetime DESC').observations rescue nil

 if hiv_staging_obs
   hiv_staging = process_hiv_staging_encounter(hiv_staging_obs)
 end

  #check if any of the strings are empty
  demographics = get_patient_demographics(patient_id, 1) if demographics.empty?
  hiv_staging = process_hiv_staging_encounter(hiv_staging_obs, 1) if hiv_staging.empty?
  hiv_clinic_registration = process_hiv_clinic_registration_encounter(hiv_clinic_reg_obs, 1) if hiv_clinic_registration.empty?
  
  #write sql statement
  table_1_sql_statement = initial_flat_table1_string + "(" + demographics[0] + "," + hiv_clinic_registration[0] + "," + hiv_staging[0] + ")" + \
  	 " VALUES (" + demographics[1] + "," + hiv_clinic_registration[1] + "," + hiv_staging[1] + ");"
  
  visits = []
  defaulted_dates = []
  patient_obj = Patient.find_by_patient_id(patient_id)
 
  visits = Encounter.find_by_sql("SELECT date(encounter_datetime) AS visit_date FROM #{@source_db}.encounter
			WHERE patient_id = #{patient_id} AND voided = 0  
			group by date(encounter_datetime)").map(&:visit_date)
  
  session_date = @max_dispensing_enc_date #date for calculating defaulters 

  defaulted_dates = patient_defaulted_dates(patient_obj, session_date) 
    
  if !defaulted_dates.blank?
    defaulted_dates.each do |date|
      if !date.blank?
        visits << date
      end
    end
  end

  #list of encounters for bart2
  #vitals => 6, appointment => 7, treatment => 25, 
  #hiv clinic consultation => 53, hiv_reception => 51
  
  initial_string = "INSERT INTO flat_table2 "
  table2_sql_batch = ""
  
  visits.sort.each do |visit|
     	# arrays of [fields, values]
      patient_details = ["patient_id, visit_date","#{patient_id},'#{visit}'"]   	
      vitals = []
      appointment = []
      hcc = []
      hiv_reception = []
      patient_orders = []
      patient_state = []
      patient_adh = []
      patient_reg_category = []

      # we will exclude the orders having drug_inventory_id null     	
      orders = Order.find_by_sql("SELECT o.patient_id, o.order_id, o.encounter_id,
                                               o.start_date, o.auto_expire_date, d.quantity,
                                               d.drug_inventory_id, d.dose, d.frequency,
                                               o.concept_id, d.equivalent_daily_dose
                                    FROM orders o
                                      INNER JOIN drug_order d ON d.order_id = o.order_id
                                    WHERE DATE(o.start_date) = '#{visit}' 
                                    AND o.patient_id = #{patient_id} 
                                    AND d.drug_inventory_id IS NOT NULL ")
      
        	if orders
          		patient_orders = process_patient_orders(orders, visit, 1) if patient_orders.empty?
        	end

          reg_category = Encounter.find_by_sql("SELECT e.patient_id, o.value_text, o.encounter_id, e.encounter_datetime
                                              FROM encounter e
                                               INNER JOIN obs o on o.encounter_id = e.encounter_id 
                                                    AND o.concept_id = 8375
                                                    AND o.voided = 0 AND e.voided = 0
                                              WHERE e.encounter_type = 54
                                              AND DATE(e.encounter_datetime) = '#{visit}'
                                              AND e.patient_id = #{patient_id}")

          if reg_category
            patient_reg_category = process_pat_regimen_category(reg_category, visit, 1) if patient_reg_category.empty?
          end

      	encounters = Encounter.find(:all,
      			:include => [:observations],
      			:order => "encounter_datetime ASC",
      			:conditions => ['voided = 0 AND patient_id = ? AND date(encounter_datetime) = ?', patient_id, visit])
      			
      	
      	encounters.each do |enc|
      		if enc.encounter_type == 6 #vitals
      			vitals = process_vitals_encounter(enc)
      		elsif enc.encounter_type == 51#HIV Reception
      			hiv_reception = process_hiv_reception_encounter(enc)
      		elsif enc.encounter_type == 53 #HIV Clinic Consultation
      			hcc = process_hiv_clinic_consultation_encounter(enc)
      		elsif enc.encounter_type == 68 #ART adherence
      		  patient_adh = process_adherence_encounter(enc, visit)
      		end
      	end
      	
      	patient_state = process_patient_state(patient_id, visit, defaulted_dates)
      	
      	#if some encounters are missing, create a skeleton with defaults
      	 vitals = process_vitals_encounter(1, 1) if vitals.empty?
         hcc = process_hiv_clinic_consultation_encounter(1, 1) if hcc.empty?
         hiv_reception = process_hiv_reception_encounter(1, 1) if hiv_reception.empty?
         patient_adh = process_adherence_encounter(1, visit,1) if patient_adh.empty?
    
         table_2_sql_statement = initial_string + "(" + patient_details[0] + "," + patient_state[0] + "," + vitals[0] + "," + hcc[0] + "," + hiv_reception[0] + "," + patient_orders[0] + "," + patient_adh[0] + "," + patient_reg_category[0] + ")" + \
           " VALUES (" + patient_details[1] + "," + patient_state[1]  + "," + vitals[1] + "," + hcc[1] + "," + hiv_reception[1] + "," + patient_orders[1] + "," + patient_adh[1] + "," + patient_reg_category[1] + ");"

      table2_sql_batch += table_2_sql_statement 

   end
   return [table_1_sql_statement, table2_sql_batch]
end

def get_patient_demographics(patient_id)
  pat = Patient.find(patient_id)
  puts patient_id.to_yaml
  patient_obj = PatientService.get_patient(pat.person) rescue nil

  earliest_start_date = PatientProgram.find_by_sql("SELECT earliest_start_date
                                           FROM earliest_start_date
                                           WHERE patient_id = #{patient_id}").map(&:earliest_start_date).first
  
  a_hash = {:legacy_id2 => 'NULL'}

  pat_attributes = {}; pat_identifier = {}

  PersonAttribute.find(:all, :conditions => ['person_id = ?', patient_id]).each do |attribute|
    pat_attributes[attribute.person_attribute_type_id] = attribute.value
  end

  PatientIdentifier.find(:all, :conditions => ['patient_id = ?', patient_id]).each do |identifier|
    pat_identifier[identifier.identifier_type] = identifier.identifier
  end

  a_hash[:patient_id] = patient_id rescue nil
  a_hash[:given_name] = pat.person.names.first.given_name  rescue nil
  a_hash[:middle_name] = pat.person.names.first.middle_name  rescue nil
  a_hash[:family_name] = pat.person.names.first.family_name  rescue nil
  a_hash[:gender] = patient_obj.sex  rescue nil
  a_hash[:dob] = pat.person.birthdate  rescue nil
  a_hash[:dob_estimated] = patient_obj.birthdate_estimated  rescue nil
  a_hash[:ta] = pat.person.addresses.first.county_district  rescue nil
  a_hash[:current_address] = pat.person.addresses.first.city_village  rescue nil
  a_hash[:home_district] = pat.person.addresses.first.address2  rescue nil
  a_hash[:landmark] = pat.person.addresses.first.address1  rescue nil
  a_hash[:cellphone_number] = pat_attributes[12]  rescue nil #cell phone
  a_hash[:home_phone_number] = pat_attributes[14]  rescue nil #home phone number
  a_hash[:office_phone_number] = pat_identifier[15]  rescue nil #office_phone_number
  a_hash[:occupation] = pat_attributes[13]  rescue nil #occupation
  a_hash[:nat_id] = pat_identifier[3]  rescue nil #national_id
  a_hash[:arv_number]  = pat_identifier[4]  rescue nil #arv_number
  a_hash[:pre_art_number] = pat_identifier[22]  rescue nil #pre_art_number
  a_hash[:tb_number]  = pat_identifier[7]  rescue nil #tb_number
  a_hash[:legacy_id]  = pat_identifier[2]  rescue nil #legacy 1
  a_hash[:prev_art_number]  = pat_identifier[5]  rescue nil #prev_arv_number
  a_hash[:filing_number]  = pat_identifier[17]  rescue nil #filing_number
  a_hash[:archived_filing_number]  = pat_identifier[18]  rescue nil #archived_filing_number
  a_hash[:earliest_start_date]  = earliest_start_date  rescue nil
  
  return generate_sql_string(a_hash)
end

def process_vitals_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash = {  :weight_enc_id => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id == 5089 #weight
        a_hash[:weight] = obs.value_numeric
		    a_hash[:weight_enc_id] = encounter.encounter_id
      elsif obs.concept_id == 5090 #height
        a_hash[:height] = obs.value_numeric
		    a_hash[:height_enc_id] = encounter.encounter_id
      elsif obs.concept_id == 5088 #temperature
        a_hash[:temperature] = obs.value_numeric
		    a_hash[:temperature_enc_id] = encounter.encounter_id
      elsif obs.concept_id == 2137 #bmi
        a_hash[:bmi] = obs.value_numeric
		    a_hash[:bmi_enc_id] = encounter.encounter_id
      elsif obs.concept_id == 5085 #systolic blood pressure
        a_hash[:systolic_blood_pressure] = obs.value_numeric
		    a_hash[:systolic_blood_pressure_enc_id] = encounter.encounter_id
      elsif obs.concept_id == 5086 #diastolic blood pressure
        a_hash[:diastolic_blood_pressure] = obs.value_numeric
		    a_hash[:diastolic_blood_pressure_enc_id] = encounter.encounter_id
      elsif obs.concept_id == 1822 #weight for height
        a_hash[:weight_for_height] = obs.value_numeric
		    a_hash[:weight_for_height_enc_id] = encounter.encounter_id
      elsif obs.concept_id == 6396 #weight for age
        a_hash[:weight_for_age] = obs.value_numeric
		    a_hash[:weight_for_age_enc_id] = encounter.encounter_id 
      elsif obs.concept_id == 6397 #height_for_age 
        a_hash[:height_for_age] = obs.value_numeric
		    a_hash[:height_for_age_enc_id] = encounter.encounter_id
      end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_reception_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =	  {:guardian_present_no_enc_id => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id == 2122 #Guardian Present
    		if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
    			a_hash[:guardian_present_yes] = 'Yes'
    			a_hash[:guardian_present_yes_enc_id] = encounter.encounter_id
    		elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
    			a_hash[:guardian_present_no] = 'No'
    			a_hash[:guardian_present_no_enc_id] = encounter.encounter_id
    		end		
      elsif obs.concept_id == 1805 #Patient Present
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_present_yes] = 'Yes'           
          a_hash[:patient_present_yes_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_present_no] = 'No'             
          a_hash[:patient_present_no_enc_id] = encounter.encounter_id
        end	
      end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_clinic_consultation_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =   {
                :routine_tb_screening_weight_loss_failure_enc_id => 'NULL'
                }

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id == 6131 #Patient Pregnant
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:pregnant_yes] = 'Yes'
          a_hash[:pregnant_yes_enc_id] = encounter.encounter_id
          a_hash[:pregnant_yes_v_date] = obs.obs_datetime.to_date                    
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:pregnant_no] = 'No'
          a_hash[:pregnant_no_enc_id] = encounter.encounter_id
          a_hash[:pregnant_no_v_date] = obs.obs_datetime.to_date                    
        end
      elsif obs.concept_id == 1755 #Patient Pregnant
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:pregnant_yes] = 'Yes'
          a_hash[:pregnant_yes_enc_id] = encounter.encounter_id
          a_hash[:pregnant_yes_v_date] = obs.obs_datetime.to_date                    
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103        
          a_hash[:pregnant_no] = 'No'
          a_hash[:pregnant_no_enc_id] = encounter.encounter_id
          a_hash[:pregnant_no_v_date] = obs.obs_datetime.to_date          
        end
      elsif obs.concept_id == 7965 #breastfeeding
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:breastfeeding_yes] = 'Yes'
          a_hash[:breastfeeding_yes_enc_id] = encounter.encounter_id
          a_hash[:breastfeeding_yes_v_date] = obs.obs_datetime.to_date          
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:breastfeeding_no] = 'No'
          a_hash[:breastfeeding_no_enc_id] = encounter.encounter_id
          a_hash[:breastfeeding_no_v_date] = obs.obs_datetime.to_date          
        end
    	elsif obs.concept_id == 7459 #tb status
    		if obs.value_coded == 7454 && obs.value_coded_name_id == 10270
    			a_hash[:tb_status_tb_not_suspected] = 'Yes'
    			a_hash[:tb_status_tb_not_suspected_enc_id] = encounter.encounter_id
    		elsif obs.value_coded == 7455 && obs.value_coded_name_id == 10273
    			a_hash[:tb_status_tb_suspected] = 'Yes'
          a_hash[:tb_status_tb_suspected_enc_id] = encounter.encounter_id
    		elsif obs.value_coded == 7456 && obs.value_coded_name_id == 10274
    			a_hash[:tb_status_confirmed_tb_not_on_treatment] = 'Yes'
          a_hash[:tb_status_confirmed_tb_not_on_treatment_enc_id] = encounter.encounter_id
    		elsif obs.value_coded == 7458 && obs.value_coded_name_id == 10279
    			a_hash[:tb_status_confirmed_tb_on_treatment] = 'Yes'
          a_hash[:tb_status_confirmed_tb_on_treatment_enc_id] = encounter.encounter_id
    		elsif obs.value_coded == 1067 && obs.value_coded_name_id == 1104
    			a_hash[:tb_status_unknown] = 'Yes'
          a_hash[:tb_status_unknown_enc_id] = encounter.encounter_id
    		end
      elsif obs.concept_id == 1717 #using family planning methods
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:currently_using_family_planning_method_yes] = 'Yes'
          a_hash[:currently_using_family_planning_method_yes_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:currently_using_family_planning_method_no] = 'No'
          a_hash[:currently_using_family_planning_method_no_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id == 374 #family planning method
        if obs.value_coded == 780 && obs.value_coded_name_id == 10736
          a_hash[:family_planning_method_oral_contraceptive_pills] = 'Yes'
          a_hash[:family_planning_method_oral_contraceptive_pills_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 907 && obs.value_coded_name_id == 931
          a_hash[:family_planning_method_depo_provera] = 'Yes'
          a_hash[:family_planning_method_depo_provera_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 5275 && obs.value_coded_name_id == 10737
          a_hash[:family_planning_method_intrauterine_contraception] = 'Yes'
          a_hash[:family_planning_method_intrauterine_contraception_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7857 && obs.value_coded_name_id == 10738
          a_hash[:family_planning_method_contraceptive_implant] = 'Yes'
          a_hash[:family_planning_method_contraceptive_implant_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7858 && obs.value_coded_name_id == 10739
          a_hash[:family_planning_method_male_condoms] = 'Yes'
          a_hash[:family_planning_method_male_condoms_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7859 && obs.value_coded_name_id == 10740
          a_hash[:family_planning_method_female_condoms] = 'Yes'
          a_hash[:family_planning_method_female_condoms_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7860 && obs.value_coded_name_id == 10741
          a_hash[:family_planning_method__rythm_method] = 'Yes'
          a_hash[:family_planning_method__rythm_method_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7861 && obs.value_coded_name_id == 10743
          a_hash[:family_planning_method_withdrawal] = 'Yes'
          a_hash[:family_planning_method_withdrawal_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1720 && obs.value_coded_name_id == 1876
          a_hash[:family_planning_method_abstinence] = 'Yes'
          a_hash[:family_planning_method_abstinence_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1719 && obs.value_coded_name_id == 1874
          a_hash[:family_planning_method_tubal_ligation] = 'Yes'
          a_hash[:family_planning_method_tubal_ligation_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1721 && obs.value_coded_name_id == 1877
          a_hash[:family_planning_method_vasectomy] = 'Yes'
          a_hash[:family_planning_method_vasectomy_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7862 && obs.value_coded_name_id == 10744
          a_hash[:family_planning_method_emergency__contraception] = 'Yes'
          a_hash[:family_planning_method_emergency__contraception_enc_id] = encounter.encounter_id
        end
     elsif obs.concept_id == 1293 #symptoms present
        if obs.value_coded == 2148 && obs.value_coded_name_id == 2325
          a_hash[:symptom_present_lipodystrophy] = 'Yes'
          a_hash[:symptom_present_lipodystrophy_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 3 && obs.value_coded_name_id == 3
          a_hash[:symptom_present_anemia] = 'Yes'
          a_hash[:symptom_present_anemia_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 215 && obs.value_coded_name_id == 226
          a_hash[:symptom_present_jaundice] = 'Yes'
          a_hash[:symptom_present_jaundice_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1458 && obs.value_coded_name_id == 1576
          a_hash[:symptom_present_lactic_acidosis] = 'Yes'
          a_hash[:symptom_present_lactic_acidosis_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 5945 && obs.value_coded_name_id == 4315
          a_hash[:symptom_present_fever] = 'Yes'
          a_hash[:symptom_present_fever_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 512 && obs.value_coded_name_id == 524
          a_hash[:symptom_present_skin_rash] = 'Yes'
          a_hash[:symptom_present_skin_rash_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 151 && obs.value_coded_name_id == 156
          a_hash[:symptom_present_abdominal_pain] = 'Yes'
          a_hash[:symptom_present_abdominal_pain_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 868 && obs.value_coded_name_id == 888
          a_hash[:symptom_present_anorexia] = 'Yes'
          a_hash[:symptom_present_anorexia_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 107 && obs.value_coded_name_id == 110
          a_hash[:symptom_present_cough] = 'Yes'
          a_hash[:symptom_present_cough_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 16 && obs.value_coded_name_id == 17
          a_hash[:symptom_present_diarrhea] = 'Yes'
          a_hash[:symptom_present_diarrhea_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7952 && obs.value_coded_name_id == 10894
          a_hash[:symptom_present_leg_pain_numbness] = 'Yes'
          a_hash[:symptom_present_leg_pain_numbness_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 821 && obs.value_coded_name_id == 838
          a_hash[:symptom_present_peripheral_neuropathy] = 'Yes'
          a_hash[:symptom_present_peripheral_neuropathy_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 5980 && obs.value_coded_name_id == 4355
          a_hash[:symptom_present_vomiting] = 'Yes'
          a_hash[:symptom_present_vomiting_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 6779 && obs.value_coded_name_id == 4355
          a_hash[:symptom_present_other_symptom] = 'Yes'
          a_hash[:symptom_present_other_symptom_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 29 && obs.value_coded_name_id == 30
          a_hash[:symptom_present_hepatitis] = 'Yes'
          a_hash[:symptom_present_hepatitis_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id == 8012 #allergic to sulpher
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:allergic_to_sulphur_yes] = 'Yes'
          a_hash[:allergic_to_sulphur_yes_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:allergic_to_sulphur_no] = 'No'
          a_hash[:allergic_to_sulphur_no_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id == 7874 #prescribe drugs
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:prescribe_arvs_yes] = 'Yes'
          a_hash[:prescribe_arvs_yes_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:prescribe_arvs_no] = 'No'
          a_hash[:prescribe_arvs_no_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id == 8259 #routine tb screening
	      if obs.value_coded == 5945 && obs.value_coded_name_id == 4315
		      a_hash[:routine_tb_screening_fever] = 'Yes'
		      a_hash[:routine_tb_screening_fever_enc_id] = encounter.encounter_id
	      elsif obs.value_coded == 6029 && obs.value_coded_name_id == 4407
		      a_hash[:routine_tb_screening_night_sweats] = 'Yes'
          a_hash[:routine_tb_screening_night_sweats_enc_id] = encounter.encounter_id
	      elsif obs.value_coded == 8261 && obs.value_coded_name_id == 11335
		      a_hash[:routine_tb_screening_cough_of_any_duration] = 'Yes'
          a_hash[:routine_tb_screening_cough_of_any_duration_enc_id] = encounter.encounter_id
	      elsif obs.value_coded == 8260 && obs.value_coded_name_id == 11333
		      a_hash[:routine_tb_screening_weight_loss_failure] = 'Yes'
          a_hash[:routine_tb_screening_weight_loss_failure_enc_id] = encounter.encounter_id
	      end
     	elsif obs.concept_id == 2146 #side effects
	      if obs.value_coded == 821 && obs.value_coded_name_id == 838
		      a_hash[:side_effects_peripheral_neuropathy] = 'Yes'
		      a_hash[:side_effects_peripheral_neuropathy_enc_id] = encounter.encounter_id
	      elsif obs.value_coded == 29 && obs.value_coded_name_id == 30
		      a_hash[:side_effects_hepatitis] = 'Yes'
          a_hash[:side_effects_hepatitis_enc_id] = encounter.encounter_id
	      elsif obs.value_coded == 512 && obs.value_coded_name_id == 524
		      a_hash[:side_effects_skin_rash] = 'Yes'
          a_hash[:side_effects_skin_rash_enc_id] = encounter.encounter_id
	      elsif obs.value_coded == 2148 && obs.value_coded_name_id == 2325
		      a_hash[:side_effects_lipodystrophy] = 'Yes'
          a_hash[:side_effects_lipodystrophy_enc_id] = encounter.encounter_id
	      elsif obs.value_coded == 6408 && obs.value_coded_name_id == 8873
		      a_hash[:side_effects_other] = 'Yes'
          a_hash[:side_effects_other_enc_id] = encounter.encounter_id
	      end
      elsif obs.concept_id == 7567 #drug induced symptoms
        if obs.value_coded == 2148 && obs.value_coded_name_id == 2325
          a_hash[:drug_induced_lipodystrophy] = 'Yes'
          a_hash[:drug_induced_lipodystrophy_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 3 && obs.value_coded_name_id == 3
          a_hash[:drug_induced_anemia] = 'Yes'
          a_hash[:drug_induced_anemia_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 215 && obs.value_coded_name_id == 226
          a_hash[:drug_induced_jaundice] = 'Yes'
          a_hash[:drug_induced_jaundice_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 1458 && obs.value_coded_name_id == 1576
          a_hash[:drug_induced_lactic_acidosis] = 'Yes'
          a_hash[:drug_induced_lactic_acidosis_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 5945 && obs.value_coded_name_id == 4315
          a_hash[:drug_induced_fever] = 'Yes'
          a_hash[:drug_induced_fever_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 512 && obs.value_coded_name_id == 524
          a_hash[:drug_induced_skin_rash] = 'Yes'
          a_hash[:drug_induced_skin_rash_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 151 && obs.value_coded_name_id == 156
          a_hash[:drug_induced_abdominal_pain] = 'Yes'
          a_hash[:drug_induced_abdominal_pain_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 868 && obs.value_coded_name_id == 888
          a_hash[:drug_induced_anorexia] = 'Yes'
          a_hash[:drug_induced_anorexia_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 107 && obs.value_coded_name_id == 110
          a_hash[:drug_induced_cough] = 'Yes'
          a_hash[:drug_induced_cough_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 16 && obs.value_coded_name_id == 17
		      a_hash[:drug_induced_diarrhea] = 'Yes'
          a_hash[:drug_induced_diarrhea_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 7952 && obs.value_coded_name_id == 10894
          a_hash[:drug_induced_leg_pain_numbness] = 'Yes'
          a_hash[:drug_induced_leg_pain_numbness_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 821 && obs.value_coded_name_id == 838
          a_hash[:drug_induced_peripheral_neuropathy] = 'Yes'
          a_hash[:drug_induced_peripheral_neuropathy_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 5980 && obs.value_coded_name_id == 4355
          a_hash[:drug_induced_vomiting] = 'Yes'
          a_hash[:drug_induced_vomiting_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 6779 && obs.value_coded_name_id == 4355
          a_hash[:drug_induced_other_symptom] = 'Yes'
          a_hash[:drug_induced_other_symptom_enc_id] = encounter.encounter_id
        elsif obs.value_coded == 29 && obs.value_coded_name_id == 30
          a_hash[:drug_induced_hepatitis] = 'Yes'
          a_hash[:drug_induced_hepatitis_enc_id] = encounter.encounter_id
        end
     	end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_clinic_registration_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

  #initialize field and values variables
  fields = ""
  values = ""

  #create hiv_clinic_registration field list hash template

  a_hash = {:date_created => 'NULL'}

  return generate_sql_string(a_hash) if type == 1

  (encounter || []).each do | obs |
    if obs.concept_id == 2552 #FOLLOW UP AGREEMENT
      a_hash[:agrees_to_followup] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7882 #CONFIRMATORY HIV TEST DATE
      a_hash[:confirmatory_hiv_test_date] = obs.value_datetime.to_date rescue nil
    elsif obs.concept_id == 7881 #CONFIRMATORY HIV TEST LOCATION
      a_hash[:confirmatory_hiv_test_location] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7750 #LOCATION OF ART INITIATION
      a_hash[:location_of_art_initialization] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7752 #HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS
      a_hash[:taken_art_in_last_two_months] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6394 #HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS
      a_hash[:taken_art_in_last_two_weeks] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6393 #HAS TRANSFER LETTER
      a_hash[:has_transfer_letter] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2516 #DATE ANTIRETROVIRALS STARTED
      a_hash[:date_started_art] = obs.value_datetime.to_date rescue nil
    elsif obs.concept_id == 7937 #EVER REGISTERED AT ART CLINIC
      a_hash[:ever_registered_at_art_clinic] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7754 #EVER RECEIVED ART?
      a_hash[:ever_received_art] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7753 #LAST ART DRUGS TAKEN
      a_hash[:last_art_drugs_taken] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7751 #DATE ART LAST TAKEN
      a_hash[:date_art_last_taken] = obs.value_datetime.to_date rescue nil
      a_hash[:date_art_last_taken_v_date] = obs.obs_datetime.to_date rescue nil      
    end
  end

  return generate_sql_string(a_hash)
end

def process_hiv_staging_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

  #initialize field and values variables
  fields = ""
  values = ""

  #create hiv_staging field list hash template
  a_hash = {
            :creator => 'NULL'
          }

  return generate_sql_string(a_hash) if type == 1

  (encounter || []).each do | obs |    
    if obs.concept_id == 6131 #Patient Pregnant
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:pregnant_yes] = 'Yes'
          a_hash[:pregnant_yes_enc_id] = obs.encounter_id
          a_hash[:pregnant_yes_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:pregnant_no] = 'No'
          a_hash[:pregnant_no_enc_id] = obs.encounter_id
          a_hash[:pregnant_no_v_date] = obs.obs_datetime.to_date
        end
    elsif obs.concept_id == 1755 #Patient Pregnant
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:pregnant_yes] = 'Yes'
          a_hash[:pregnant_yes_enc_id] = obs.encounter_id
          a_hash[:pregnant_yes_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:pregnant_no] = 'No'
          a_hash[:pregnant_no_enc_id] = obs.encounter_id
          a_hash[:pregnant_no_v_date] = obs.obs_datetime.to_date          
        end
    elsif obs.concept_id == 7965 #breastfeeding
        if obs.value_coded == 1065 && obs.value_coded_name_id == 1102
          a_hash[:breastfeeding_yes] = 'Yes'
          a_hash[:breastfeeding_yes_enc_id] = obs.encounter_id
          a_hash[:breastfeeding_yes_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded == 1066 && obs.value_coded_name_id == 1103
          a_hash[:breastfeeding_no] = 'No'
          a_hash[:breastfeeding_no_enc_id] = obs.encounter_id
          a_hash[:breastfeeding_no_v_date]  = obs.obs_datetime.to_date                    
        end
    elsif obs.concept_id == 9099 #cd4 count location
      a_hash[:cd4_count_location] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5497 #cd4_count
      a_hash[:cd4_count] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 9098 #cd4_count_modifier
      a_hash[:cd4_count_modifier] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 730 #cd4_count_percent
      a_hash[:cd4_count_percent] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6831 #cd4_count_datetime
      a_hash[:cd4_count_datetime] = obs.value_datetime.to_date rescue nil
    elsif obs.concept_id == 5006 #asymptomatic
      a_hash[:asymptomatic] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5328 #persistent_generalized_lymphadenopathy
      a_hash[:persistent_generalized_lymphadenopathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6757 #unspecified_stage_1_cond
      a_hash[:unspecified_stage_1_cond] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1212 #molluscumm_contagiosum
      a_hash[:molluscumm_contagiosum] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6775 #wart_virus_infection_extensive
      a_hash[:wart_virus_infection_extensive] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2576 #oral_ulcerations_recurrent
      a_hash[:oral_ulcerations_recurrent] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1210 #parotid_enlargement_persistent_unexplained
      a_hash[:parotid_enlargement_persistent_unexplained] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2891 #lineal_gingival_erythema
      a_hash[:lineal_gingival_erythema] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 836 #herpes_zoster
      a_hash[:herpes_zoster] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5012 #respiratory_tract_infections_recurrent
      a_hash[:respiratory_tract_infections_recurrent] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6758 #unspecified_stage2_condition
      a_hash[:unspecified_stage2_condition] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2575 #angular_chelitis
      a_hash[:angular_chelitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2577 #papular_pruritic_eruptions
      a_hash[:papular_pruritic_eruptions] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7537 #hepatosplenomegaly_unexplained
      a_hash[:hepatosplenomegaly_unexplained] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5337 #oral_hairy_leukoplakia
      a_hash[:oral_hairy_leukoplakia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7540 #severe_weight_loss
      a_hash[:severe_weight_loss] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5027 #fever_persistent_unexplained
      a_hash[:fever_persistent_unexplained] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 8206 #pulmonary_tuberculosis
      a_hash[:pulmonary_tuberculosis] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 7539 #pulmonary_tuberculosis_last_2_years
      a_hash[:pulmonary_tuberculosis_last_2_years] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 5333 #severe_bacterial_infection
      a_hash[:severe_bacterial_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1215 #bacterial_pnuemonia
      a_hash[:bacterial_pnuemonia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5024 #symptomatic_lymphoid_interstitial_pnuemonitis
      a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2889 #chronic_hiv_assoc_lung_disease
      a_hash[:chronic_hiv_assoc_lung_disease] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6759 #unspecified_stage3_condition
      a_hash[:unspecified_stage3_condition] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 3 #aneamia
      a_hash[:aneamia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7954 #neutropaenia
      a_hash[:neutropaenia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7955 #thrombocytopaenia_chronic
      a_hash[:thrombocytopaenia_chronic] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 16 #diarhoea
      a_hash[:diarhoea] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5334 #oral_candidiasis
      a_hash[:oral_candidiasis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7546 #acute_necrotizing_ulcerative_gingivitis
      a_hash[:acute_necrotizing_ulcerative_gingivitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7547 #lymph_node_tuberculosis
      a_hash[:lymph_node_tuberculosis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2583 #toxoplasmosis_of_the_brain
      a_hash[:toxoplasmosis_of_the_brain] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1359 #cryptococcal_meningitis
      a_hash[:cryptococcal_meningitis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5046 #progressive_multifocal_leukoencephalopathy
      a_hash[:progressive_multifocal_leukoencephalopathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7550 #disseminated_mycosis
      a_hash[:disseminated_mycosis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7553 #candidiasis_of_oesophagus
      a_hash[:candidiasis_of_oesophagus] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 1547 #extrapulmonary_tuberculosis
      a_hash[:extrapulmonary_tuberculosis] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:extrapulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 2587 #cerebral_non_hodgkin_lymphoma
      a_hash[:cerebral_non_hodgkin_lymphoma] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 507 #kaposis
      a_hash[:kaposis_sarcoma] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:kaposis_sarcoma_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 1362 #hiv_encephalopathy
      a_hash[:hiv_encephalopathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2894 #bacterial_infections_severe_recurrent
      a_hash[:bacterial_infections_severe_recurrent] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 6763 #unspecified_stage_4_condition
      a_hash[:unspecified_stage_4_condition] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 882 #pnuemocystis_pnuemonia
      a_hash[:pnuemocystis_pnuemonia] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2585 #disseminated_non_tuberculosis_mycobacterial_infection
      a_hash[:disseminated_non_tuberculosis_mycobacterial_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5034 #cryptosporidiosis
      a_hash[:cryptosporidiosis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2858 #isosporiasis
      a_hash[:isosporiasis] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7957 #symptomatic_hiv_associated_nephropathy
      a_hash[:symptomatic_hiv_associated_nephropathy] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5344 #chronic_herpes_simplex_infection
      a_hash[:chronic_herpes_simplex_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7551 #cytomegalovirus_infection
      a_hash[:cytomegalovirus_infection] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 5048 #toxoplasomis_of_the_brain_1month
      a_hash[:toxoplasomis_of_the_brain_1month] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7961 #recto_vaginal_fitsula
      a_hash[:recto_vaginal_fitsula] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 823 #moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl
      a_hash[:moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 7563 #reason_for_starting_art
      a_hash[:reason_for_eligibility] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:reason_for_starting_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id == 7562 #who_stage
      a_hash[:who_stage] = obs.to_s.split(':')[1].strip rescue nil
    elsif obs.concept_id == 2743 #who_stage_criteria_present
      a_hash[:who_stages_criteria_present] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:who_stages_criteria_present_enc_id] = obs.encounter_id rescue nil
      a_hash[:who_stages_criteria_present_v_date] = obs.obs_datetime.to_date rescue nil
    else
    end
  end

  return generate_sql_string(a_hash)
end

def process_pat_regimen_category(reg_category, visit, type = 0)
  a_hash = {:transfer_within_responsibility_no => 'NULL'}

  if reg_category
    (reg_category || []).each do |regimen|
      a_hash[:regimen_category] = regimen.value_text
      a_hash[:regimen_category_enc_id] = regimen.encounter_id
    end
   
    return generate_sql_string(a_hash)
  end
end

def process_patient_orders(orders, visit, type = 0)
  patient_orders = {}
  drug_dose_hash = {}; drug_frequency_hash = {};
  drug_equivalent_daily_dose_hash = {}; drug_inventory_ids_hash = {}
  patient_orders = {}; drug_order_ids_hash = {}; drug_enc_ids_hash = {}
  drug_start_date_hash = {}; drug_auto_expire_date_hash = {}; drug_quantity_hash = {}
  
  a_hash = {:arv_regimen_type_AZT_3TC_AZT_3TC_NVP_enc_id => 'NULL'}
  
  if !orders.blank?  
    patient_id = orders.map(&:patient_id).first
  end
    
  (orders || []).each do |ord|
    if ord.drug_inventory_id == '2833'
      drug_name = @drug_list[:"738"] 
    elsif ord.drug_inventory_id == '1610'
      drug_name = @drug_list[:"731"] 
    elsif ord.drug_inventory_id == '1613'
      drug_name = @drug_list[:"955"] 
    elsif ord.drug_inventory_id == '2985'
      drug_name = @drug_list[:"735"] 
    elsif ord.drug_inventory_id == '7927'
      drug_name = @drug_list[:"969"] 
    elsif ord.drug_inventory_id == '7928'
      drug_name = @drug_list[:"734"] 
    elsif ord.drug_inventory_id == '9175'
      drug_name = @drug_list[:"932"] 
    else
      drug_name = @drug_list[:"#{ord.drug_inventory_id}"] 
    end
      
    if patient_orders[drug_name].blank?
      patient_orders[drug_name] = drug_name
      drug_order_ids_hash[drug_name] = ord.order_id
      drug_enc_ids_hash[drug_name] = ord.encounter_id
      drug_start_date_hash[drug_name] = ord.start_date.strftime("%Y-%m-%d")  rescue nil
      drug_auto_expire_date_hash[drug_name] = ord.auto_expire_date.strftime("%Y-%m-%d")  rescue nil
      drug_quantity_hash[drug_name] = ord.quantity rescue nil
      drug_dose_hash[drug_name] = ord.dose
      drug_frequency_hash[drug_name] = ord.frequency
      drug_equivalent_daily_dose_hash[drug_name] = ord.equivalent_daily_dose
      drug_inventory_ids_hash[drug_name] = ord.drug_inventory_id
    else
      patient_orders[drug_name] += drug_name
      drug_order_ids_hash[drug_name] += ord.order_id
      drug_enc_ids_hash[drug_name] += ord.encounter_id
      drug_start_date_hash[drug_name] += ord.start_date.strftime("%Y-%m-%d")  rescue nil
      drug_auto_expire_date_hash[drug_name] += ord.auto_expire_date.strftime("%Y-%m-%d")  rescue nil
      drug_quantity_hash[drug_name] += ord.quantity rescue nil
      drug_dose_hash[drug_name] += ord.dose
      drug_frequency_hash[drug_name] += ord.frequency
      drug_equivalent_daily_dose_hash[drug_name] += ord.equivalent_daily_dose
      drug_inventory_ids_hash[drug_name] += ord.drug_inventory_id
    end
  end
 
  count = 1
  (patient_orders).each do |drug_name, name|
    case count
      when 1
       a_hash[:drug_name1] = drug_name
       a_hash[:drug_order_id1] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date1] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date1] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity1] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency1] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose1] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose1] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id1] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id1] = drug_inventory_ids_hash[drug_name] 
       count += 1
      when 2
       a_hash[:drug_name2] = drug_name
       a_hash[:drug_order_id2] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date2] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date2] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity2] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency2] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose2] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose2] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id2] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id2] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 3
       a_hash[:drug_name3] = drug_name
       a_hash[:drug_order_id3] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date3] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date3] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity3] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency3] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose3] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose3] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id3] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id3] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 4
       a_hash[:drug_name4] = drug_name
       a_hash[:drug_order_id4] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date4] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date4] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity4] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency4] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose4] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose4] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id4] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id4] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 5
       a_hash[:drug_name5] = drug_name
       a_hash[:drug_order_id5] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date5] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date5] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity5] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency5] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose5] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose5] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id5] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id5] = drug_inventory_ids_hash[drug_name]
       count += 1    
      end
  end

  return generate_sql_string(a_hash)
end

def process_patient_state(patient_id,visit, defaulted_dates)
	#initialize field and values variables
  	fields = ""
  	values = ""

	a_hash = {:current_hiv_program_start_date => 'NULL'}

	program_id = PatientProgram.find_by_sql("SELECT patient_program_id 
				FROM patient_program 
				WHERE patient_id = #{patient_id} 
				AND program_id = 1 AND voided = 0 
				ORDER BY patient_program_id DESC LIMIT 1").first.patient_program_id

  if defaulted_dates.include?(visit)
    state_name = 'Defaulter'
  else
    patient_state = PatientProgram.find_by_sql("SELECT 
	                        current_state_for_program(#{patient_id},1,'#{visit} 23:59:59') AS state").first.state  
	  
	   if !patient_state.blank?
      state_name = ProgramWorkflowState.find_by_sql("SELECT 
                                             c.name AS name
                                           FROM
                                                program_workflow_state pws
                                                    INNER JOIN
                                                concept_name c ON c.concept_id = pws.concept_id
                                                    AND c.voided = 0
                                                    AND pws.retired = 0
                                           WHERE
                                                program_workflow_state_id = #{patient_state}
                                                    and program_workflow_id = 1
                                            LIMIT 1").map(&:name) #rescue nil
    end
  end

  
 
  a_hash[:current_hiv_program_state] = state_name
	a_hash[:current_hiv_program_start_date] = visit

	return generate_sql_string(a_hash)
end

def process_adherence_encounter(encounter, visit, type = 0) #type 0 normal encounter, 1 generate_template only 
    patient_adh = {}
    amount_of_drug_brought_to_clinic_hash  = {}
    missed_hiv_drug_const_hash  = {}
    patient_adherence_hash  = {}
    patient_adherence_enc_ids = {}
    amount_of_drug_remaining_at_home_hash  = {}

    #initialize field and values variables
    fields = ""
    values = ""

    #create patient adherence field list hash template
    a_hash = {:missed_hiv_drug_construct1 => 'NULL'}

    return generate_sql_string(a_hash) if type == 1
if encounter != 1
    (encounter.observations || []).each do |adh|
      if patient_adh[visit].blank?
        patient_adh[visit] = visit
        if adh.concept_id == 2540 #amount brought
          amount_of_drug_brought_to_clinic_hash[visit] = adh.to_s.split(':')[1].strip rescue nil
        elsif adh.concept_id == 2667 #missed hiv drug
          missed_hiv_drug_const_hash[visit] = adh.to_s.split(':')[1].strip rescue nil
        elsif adh.concept_id == 6987 #patient adherence
          patient_adherence_hash[visit] = adh.value_text rescue nil
          patient_adherence_enc_ids[visit] = adh.encounter_id rescue nil
        elsif adh.concept_id == 6781 #amount remaining
          amount_of_drug_remaining_at_home_hash[visit] = adh.to_s.split(':')[1].strip rescue nil
        end
      else
        patient_adh[visit] += visit
        if adh.concept_id == 2540 #amount brought
          amount_of_drug_brought_to_clinic_hash[visit] += adh.to_s.split(':')[1].strip rescue nil
        elsif adh.concept_id == 2667 #missed hiv drug
          missed_hiv_drug_const_hash[visit] += adh.to_s.split(':')[1].strip rescue nil
        elsif adh.concept_id == 6987 #patient adherence
          patient_adherence_hash[visit] = adh.value_text rescue nil
          patient_adherence_enc_ids[visit] = adh.encounter_id rescue nil
        elsif adh.concept_id == 6781 #amount remaining
          amount_of_drug_remaining_at_home_hash[visit] += adh.to_s.split(':')[1].strip rescue nil
        end
      end
    end
#raise patient_adh.to_yaml
end
    count = 1
    (patient_adh || []).each do |visit, data|

      case count
        when 1
         a_hash[:amount_of_drug1_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[visit]
         a_hash[:amount_of_drug1_remaining_at_home] = amount_of_drug_remaining_at_home_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug1] = patient_adherence_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug1_enc_id] = patient_adherence_enc_ids[visit]
         a_hash[:missed_hiv_drug_construct1] = missed_hiv_drug_const_hash[visit]
         count += 1
        when 2
         a_hash[:amount_of_drug2_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[visit]
         a_hash[:amount_of_drug2_remaining_at_home] = amount_of_drug_remaining_at_home_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug2] = patient_adherence_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug2_enc_id] = patient_adherence_enc_ids[visit]
         a_hash[:missed_hiv_drug_construct2] = missed_hiv_drug_const_hash[visit]
         count += 1
        when 3
         a_hash[:amount_of_drug3_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[visit]
         a_hash[:amount_of_drug3_remaining_at_home] = amount_of_drug_remaining_at_home_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug3] = patient_adherence_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug3_enc_id] = patient_adherence_enc_ids[visit]         
         a_hash[:missed_hiv_drug_construct3] = missed_hiv_drug_const_hash[visit]
         count += 1
        when 4
         a_hash[:amount_of_drug4_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[visit]
         a_hash[:amount_of_drug4_remaining_at_home] = amount_of_drug_remaining_at_home_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug4] = patient_adherence_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug4_enc_id] = patient_adherence_enc_ids[visit]         
         a_hash[:missed_hiv_drug_construct4] = missed_hiv_drug_const_hash[visit]
         count += 1
        when 5
         a_hash[:amount_of_drug5_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[visit]
         a_hash[:amount_of_drug5_remaining_at_home] = amount_of_drug_remaining_at_home_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug5] = patient_adherence_hash[visit]
         a_hash[:what_was_the_patient_adherence_for_this_drug5_enc_id] = patient_adherence_enc_ids[visit]         
         a_hash[:missed_hiv_drug_construct5] = missed_hiv_drug_const_hash[visit]
         count += 1    
     end
    end

  return generate_sql_string(a_hash)
end

def patient_defaulted_dates(patient_obj, session_date)
    #getting all patient's dispensations encounters
    
    all_dispensations = Observation.find_by_sql("SELECT obs.person_id, obs.obs_datetime AS obs_datetime, d.order_id
                            FROM drug_order d 
                              LEFT JOIN orders o ON d.order_id = o.order_id
                              LEFT JOIN obs ON d.order_id = obs.order_id
                            WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug
                                                          WHERE concept_id IN (SELECT concept_id 
                                                                               FROM concept_set
                                                                               WHERE concept_set = 1085))
                                                          AND quantity > 0
                                                          AND obs.voided = 0
                                                          AND o.voided = 0
                                                          and obs.person_id = #{patient_obj.patient_id}
                                                          GROUP BY DATE(obs_datetime) order by obs_datetime")
    
    outcome_dates = []
    dates = 0
    total_dispensations = all_dispensations.length
    defaulted_dates = all_dispensations.map(&:obs_datetime)
    test = []
    
    all_dispensations.each do |disp_date|
      d = ((dates - total_dispensations) + 1)

      prev_dispenation_date = all_dispensations[d].obs_datetime.to_date

      if (d == 0 && dates ==0) or (d != 0)
        if d == 0
          previous_date = session_date
          defaulted_date = ActiveRecord::Base.connection.select_value "                   
          SELECT current_defaulter_date(#{disp_date.person_id}, '#{previous_date}')"
          
          if !defaulted_date.blank?
            outcome_dates << defaulted_date if !outcome_dates.include?(defaulted_date)
          end
        else
          if d == -1
            previous_date = session_date
          else
            previous_date = prev_dispenation_date
          end          
          defaulted_date = ActiveRecord::Base.connection.select_value "
              SELECT current_defaulter_date(#{disp_date.person_id}, '#{previous_date}')"
              
          if !defaulted_date.blank? 
            outcome_dates << defaulted_date if !outcome_dates.include?(defaulted_date)
          end
        end
        dates += 1
      end
    end

    return outcome_dates
end

def generate_sql_string(a_hash)
   fields = ""
   values = ""

    a_hash.each do |key,value|
        fields += fields.empty? ? "`#{key}`" : ", `#{key}`"
      	str = '"' + value.to_s + '"'
        values += values.empty? ? "#{str}" : ", #{str}"
    end

    return [fields, values]
end

def start
 initialize_variables
 #get_all_patients
 initiate_script
end

def get_drug_list
  drug_hash = {}
  drug_list = Drug.find_by_sql("SELECT drug_id, name FROM drug")
  drug_list.each do |drug|
    drug_hash[:"#{drug.drug_id}"] = drug.name 
  end
  return drug_hash
end

start 
