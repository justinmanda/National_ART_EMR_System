require 'yaml'

def initialize_variables
  @source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))["development"]["database"]
  @started_at = Time.now.strftime("%Y-%m-%d-%H%M%S")
end

def write_sql(a_hash,table)

    #open the necessary output file for writing
    if table == 'f1'
        $temp_outfile = File.open("./migration_output/flat_table_1-" + @started_at + ".sql", "w")
	initial_text = "INSERT INTO flat_table1 "
    elsif table == 'f2'
 	$temp_outfile = File.open("./migration_output/flat_table_2-" + @started_at + ".sql", "w") 
	initial_text = "INSERT INTO flat_table2 "
    elsif table == 'cft'
	$temp_outfile = File.open("./migration_output/cohort_flat_table-" + @started_at + ".sql", "w")
	initial_text = "INSERT INTO cohort_flat_table "
    else
	raise "Invalid table"
    end
    #initialize field and values variables
    fields = ""
    values = ""
    #create sql statement
    a_hash.each do |key,value|
	fields += fields.empty? ? "`#{key}`" : ", `#{key}`"
	values += values.empty? ? "`#{value}`" : ", `#{value}`"	
    end
    full_string = initial_text + "(" + fields + ")" + " VALUES (" + values + ");"
    
    #write to output file
    $temp_outfile << full_string

    #close the output file
    $temp_outfile.close
end

def get_all_patients
    puts "started at #{@started_at}"
    #open files for writing
    $temp_outfile_1 = File.open("./db/flat_tables_init_output/flat_cohort_table-" + @started_at + ".sql", "w")
    $temp_outfile_3 = File.open("./db/flat_tables_init_output/patients_initialized_in_flat_cohort_table-" + @started_at + ".sql", "w")
    
    patient_list = Patient.find_by_sql("SELECT patient_id FROM #{@source_db}.flat_table1").map(&:patient_id)
    patient_list.each do |p|
         $temp_outfile_3 << "#{p}," 
	       sql_statements = get_patients_data(p)
      	 $temp_outfile_1 << sql_statements[0]
    end
    #close files 
    $temp_outfile_1.close
    $temp_outfile_3.close
    
    puts "ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")}"
end

def get_patients_data(patient_id)
   #building flat_cohort_table

   initial_flat_table1_string = "INSERT INTO flat_cohort_table "
   
   flat_table_1_data = []; flat_table_2_data = [] 
    
   #get flat_table1 data
   flat_table_1_data = Encounter.find_by_sql("SELECT
                                                patient_id,
                                                gender,
                                                dob,
                                                earliest_start_date,
                                                reason_for_eligibility,
                                                ever_registered_at_art_clinic,
                                                date_art_last_taken,
                                                taken_art_in_last_two_months,
                                                taken_art_in_last_two_weeks,
                                                extrapulmonary_tuberculosis,
                                                pulmonary_tuberculosis,
                                                pulmonary_tuberculosis_last_2_years,
                                                kaposis_sarcoma,
                                                extrapulmonary_tuberculosis_v_date,
                                                pulmonary_tuberculosis_v_date,
                                                pulmonary_tuberculosis_last_2_years_v_date,
                                                kaposis_sarcoma_v_date,
                                                reason_for_starting_v_date,
                                                ever_registered_at_art_v_date,
                                                date_art_last_taken_v_date,
                                                date_art_last_taken_v_date,
                                                taken_art_in_last_two_months_v_date
                                              FROM #{@source_db}.flat_table1
                                              WHERE patient_id = #{patient_id}")

   if flat_table_1_data
      flat_table1 = process_flat_table_1(flat_table_1_data)
   end

   #get flat_table2 data
    flat_table_2_data = Encounter.find_by_sql("SELECT
                              patient_id,
                              visit_date,
                              pregnant_yes,
                              pregnant_no,
                              drug_induced_abdominal_pain,
                              drug_induced_anorexia,
                              drug_induced_diarrhea,
                              drug_induced_jaundice,
                              drug_induced_leg_pain_numbness,
                              drug_induced_vomiting,
                              drug_induced_peripheral_neuropathy,
                              drug_induced_hepatitis,
                              drug_induced_anemia,
                              drug_induced_lactic_acidosis,
                              drug_induced_lipodystrophy,
                              drug_induced_skin_rash,
                              drug_induced_other_symptom,
                              drug_induced_fever,
                              drug_induced_cough,
                              tb_status_tb_not_suspected,
                              tb_status_tb_suspected,
                              tb_status_confirmed_tb_not_on_treatment,
                              tb_status_confirmed_tb_on_treatment,
                              tb_status_unknown,
                              regimen_category,
                              drug_auto_expire_date1,
                              drug_inventory_id1,
                              drug_name1,
                              drug_auto_expire_date2,
                              drug_inventory_id2,
                              drug_name2,
                              drug_auto_expire_date3,
                              drug_inventory_id3,
                              drug_name3,
                              drug_auto_expire_date4,
                              drug_inventory_id4,
                              drug_name4,
                              drug_inventory_id5,
                              drug_name5,
                              drug_equivalent_daily_dose5,
                              what_was_the_patient_adherence_for_this_drug1,
                              what_was_the_patient_adherence_for_this_drug2,
                              what_was_the_patient_adherence_for_this_drug3,
                              what_was_the_patient_adherence_for_this_drug4,
                              what_was_the_patient_adherence_for_this_drug5,
                              current_hiv_program_state,
                              current_hiv_program_start_date,
                              current_hiv_program_end_date
                            FROM #{@source_db}.flat_table2
                            WHERE patient_id = #{patient_id}
                            ORDER BY visit_date DESC
                            LIMIT 1")
                        
   if flat_table_2_data
      flat_table2 = process_flat_table_2(flat_table_2_data)
   end
  #check if any of the strings are empty
  flat_table1 = process_flat_table_1(flat_table_1_data) if flat_table1.empty?
  flat_table2 = process_flat_table_2(flat_table_2_data) if flat_table2.empty?

  #write sql statement
  #raise hiv_staging[1].to_yaml
  flat_cohort_table_sql_statement = initial_flat_table1_string + "(" + flat_table1[0] + "," + flat_table2[0] + ")" + \
		 " VALUES (" + flat_table1[1] + "," + flat_table2[1] + ");"

   return [flat_cohort_table_sql_statement]
end

def process_flat_table_1(flat_table_1_data, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create flat_table1 field list hash template
    a_hash = {  :ever_registered_at_art_v_date => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    (flat_table_1_data || []).each do |patient|
    
      pat = Patient.find_by_patient_id(patient.patient_id)

      a_hash[:patient_id] = patient.patient_id
      a_hash[:gender] = patient.gender
      a_hash[:birthdate] = patient.dob
      a_hash[:death_date] = pat.person.death_date
      a_hash[:earliest_start_date] = patient.earliest_start_date
      a_hash[:reason_for_starting] = patient.reason_for_eligibility
      a_hash[:ever_registered_at_art] = patient.ever_registered_at_art_clinic
      a_hash[:date_art_last_taken] = patient.date_art_last_taken
      a_hash[:taken_art_in_last_two_months] = patient.taken_art_in_last_two_months
      a_hash[:extrapulmonary_tuberculosis] = patient.extrapulmonary_tuberculosis
      a_hash[:pulmonary_tuberculosis] = patient.pulmonary_tuberculosis
      a_hash[:pulmonary_tuberculosis_last_2_years] = patient.pulmonary_tuberculosis_last_2_years
      a_hash[:kaposis_sarcoma] = patient.kaposis_sarcoma
      a_hash[:extrapulmonary_tuberculosis_v_date] = patient.extrapulmonary_tuberculosis_v_date
      a_hash[:pulmonary_tuberculosis_v_date] = patient.pulmonary_tuberculosis_v_date
      a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = patient.pulmonary_tuberculosis_last_2_years_v_date
      a_hash[:kaposis_sarcoma_v_date] = patient.kaposis_sarcoma_v_date
      a_hash[:reason_for_starting_v_date] = patient.reason_for_starting_v_date
      a_hash[:ever_registered_at_art_v_date] = patient.ever_registered_at_art_v_date
      a_hash[:date_art_last_taken_v_date] = patient.date_art_last_taken_v_date
      a_hash[:taken_art_in_last_two_months_v_date] = patient.taken_art_in_last_two_months_v_date
   end

    return generate_sql_string(a_hash)
end

def process_flat_table_2(flat_table_2_data, type = 0) #type 0 normal encounter, 1 generate_template only 

    #initialize field and values variables
    fields = ""
    values = ""

    #create flat_table2 field list hash template
    a_hash = {  :drug_auto_expire_date5_v_date => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    (flat_table_2_data || []).each do |patient|
      a_hash[:hiv_program_state] = patient.current_hiv_program_state
      a_hash[:hiv_program_start_date] = patient.current_hiv_program_start_date
      a_hash[:pregnant_yes] = patient.pregnant_yes
      a_hash[:pregnant_no] = patient.pregnant_no
      a_hash[:drug_induced_abdominal_pain] = patient.drug_induced_abdominal_pain
      a_hash[:drug_induced_anorexia] = patient.drug_induced_anorexia
      a_hash[:drug_induced_diarrhea] = patient.drug_induced_diarrhea
      a_hash[:drug_induced_jaundice] = patient.drug_induced_jaundice
      a_hash[:drug_induced_leg_pain_numbness] = patient.drug_induced_leg_pain_numbness
      a_hash[:drug_induced_vomiting] = patient.drug_induced_vomiting
      a_hash[:drug_induced_peripheral_neuropathy] = patient.drug_induced_peripheral_neuropathy
      a_hash[:drug_induced_hepatitis] = patient.drug_induced_hepatitis
      a_hash[:drug_induced_anemia] = patient.drug_induced_anemia
      a_hash[:drug_induced_lactic_acidosis] = patient.drug_induced_lactic_acidosis
      a_hash[:drug_induced_lipodystrophy] = patient.drug_induced_lipodystrophy
      a_hash[:drug_induced_skin_rash] = patient.drug_induced_skin_rash
      a_hash[:drug_induced_other_symptom] = patient.drug_induced_other_symptom
      a_hash[:drug_induced_fever] = patient.drug_induced_fever
      a_hash[:drug_induced_cough] = patient.drug_induced_cough
      a_hash[:tb_not_suspected] = patient.tb_status_tb_not_suspected
      a_hash[:tb_suspected] = patient.tb_status_tb_suspected
      a_hash[:confirmed_tb_not_on_treatment] = patient.tb_status_confirmed_tb_not_on_treatment
      a_hash[:confirmed_tb_on_treatment] = patient.tb_status_confirmed_tb_on_treatment
      a_hash[:unknown_tb_status] = patient.tb_status_unknown
      a_hash[:regimen_category] = patient.regimen_category
      a_hash[:what_was_the_patient_adherence_for_this_drug1] = patient.what_was_the_patient_adherence_for_this_drug1
      a_hash[:what_was_the_patient_adherence_for_this_drug2] = patient.what_was_the_patient_adherence_for_this_drug2
      a_hash[:what_was_the_patient_adherence_for_this_drug3] = patient.what_was_the_patient_adherence_for_this_drug3
      a_hash[:what_was_the_patient_adherence_for_this_drug4] = patient.what_was_the_patient_adherence_for_this_drug4
      a_hash[:what_was_the_patient_adherence_for_this_drug5] = patient.what_was_the_patient_adherence_for_this_drug5
      a_hash[:drug_name1] = patient.drug_name1
      a_hash[:drug_name2] = patient.drug_name2
      a_hash[:drug_name3] = patient.drug_name3
      a_hash[:drug_name4] = patient.drug_name4
      a_hash[:drug_name5] = patient.drug_name5
      a_hash[:drug_inventory_id1] = patient.drug_inventory_id1
      a_hash[:drug_inventory_id2] = patient.drug_inventory_id2
      a_hash[:drug_inventory_id3] = patient.drug_inventory_id3
      a_hash[:drug_inventory_id4] = patient.drug_inventory_id4
      a_hash[:drug_inventory_id5] = patient.drug_inventory_id5
      a_hash[:drug_auto_expire_date1] = patient.drug_auto_expire_date1
      a_hash[:drug_auto_expire_date2] = patient.drug_auto_expire_date2
      a_hash[:drug_auto_expire_date3] = patient.drug_auto_expire_date3
      a_hash[:drug_auto_expire_date4] = patient.drug_auto_expire_date4
      a_hash[:drug_auto_expire_date5] = patient.drug_equivalent_daily_dose5
      a_hash[:hiv_program_state_v_date] = patient.visit_date
      a_hash[:hiv_program_start_date_v_date] = patient.visit_date
      a_hash[:current_tb_status_v_date] = patient.visit_date
      a_hash[:pregnant_yes_v_date] = patient.visit_date
      a_hash[:pregnant_no_v_date] = patient.visit_date
      a_hash[:death_date_v_date] = patient.visit_date
      a_hash[:drug_induced_abdominal_pain_v_date] = patient.visit_date
      a_hash[:drug_induced_anorexia_v_date] = patient.visit_date
      a_hash[:drug_induced_diarrhea_v_date] = patient.visit_date
      a_hash[:drug_induced_jaundice_v_date] = patient.visit_date
      a_hash[:drug_induced_leg_pain_numbness_v_date] = patient.visit_date
      a_hash[:drug_induced_vomiting_v_date] = patient.visit_date
      a_hash[:drug_induced_peripheral_neuropathy_v_date] = patient.visit_date
      a_hash[:drug_induced_hepatitis_v_date] = patient.visit_date
      a_hash[:drug_induced_anemia_v_date] = patient.visit_date
      a_hash[:drug_induced_lactic_acidosis_v_date] = patient.visit_date
      a_hash[:drug_induced_lipodystrophy_v_date] = patient.visit_date
      a_hash[:drug_induced_skin_rash_v_date] = patient.visit_date
      a_hash[:drug_induced_other_symptom_v_date] = patient.visit_date
      a_hash[:drug_induced_fever_v_date] = patient.visit_date
      a_hash[:drug_induced_cough_v_date] = patient.visit_date
      a_hash[:tb_not_suspected_v_date] = patient.visit_date
      a_hash[:tb_suspected_v_date] = patient.visit_date
      a_hash[:confirmed_tb_not_on_treatment_v_date] = patient.visit_date
      a_hash[:confirmed_tb_on_treatment_v_date] = patient.visit_date
      a_hash[:unknown_tb_status_v_date] = patient.visit_date
      a_hash[:what_was_the_patient_adherence_for_this_drug1_v_date] = patient.visit_date
      a_hash[:what_was_the_patient_adherence_for_this_drug2_v_date] = patient.visit_date
      a_hash[:what_was_the_patient_adherence_for_this_drug3_v_date] = patient.visit_date
      a_hash[:what_was_the_patient_adherence_for_this_drug4_v_date] = patient.visit_date
      a_hash[:what_was_the_patient_adherence_for_this_drug5_v_date] = patient.visit_date
      a_hash[:regimen_category_v_date] = patient.visit_date
      a_hash[:drug_name1_v_date] = patient.visit_date
      a_hash[:drug_name2_v_date] = patient.visit_date
      a_hash[:drug_name3_v_date] = patient.visit_date
      a_hash[:drug_name4_v_date] = patient.visit_date
      a_hash[:drug_name5_v_date] = patient.visit_date
      a_hash[:drug_inventory_id1_v_date] = patient.visit_date
      a_hash[:drug_inventory_id2_v_date] = patient.visit_date
      a_hash[:drug_inventory_id3_v_date] = patient.visit_date
      a_hash[:drug_inventory_id4_v_date] = patient.visit_date
      a_hash[:drug_inventory_id5_v_date] = patient.visit_date
      a_hash[:drug_auto_expire_date1_v_date] = patient.visit_date
      a_hash[:drug_auto_expire_date2_v_date] = patient.visit_date
      a_hash[:drug_auto_expire_date3_v_date] = patient.visit_date
      a_hash[:drug_auto_expire_date4_v_date] = patient.visit_date
      a_hash[:drug_auto_expire_date5_v_date] = patient.visit_date
   end

    return generate_sql_string(a_hash)
end

def generate_sql_string(a_hash)
   fields = ""
   values = ""

    a_hash.each do |key,value|
        fields += fields.empty? ? "`#{key}`" : ", `#{key}`"
	      
	      str = '"' + value.to_s + '"'
#        values += values.empty? ? "'#{value}'" : ", '#{value}'"
        values += values.empty? ? "#{str}" : ", #{str}"
    end

    return [fields, values]
end

def start
 initialize_variables
 get_all_patients
end

start 
