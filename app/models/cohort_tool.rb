class CohortTool < ActiveRecord::Base
  set_table_name "encounter"
  
  def self.survival_analysis(survival_start_date=@start_date,
                        survival_end_date=@end_date,
                        outcome_end_date=@end_date, min_age=nil, max_age=nil)
    # Make sure these are always dates
    survival_start_date = survival_start_date.to_date
    survival_end_date = survival_end_date.to_date
    outcome_end_date = outcome_end_date.to_date

    date_ranges = Array.new
    first_registration_date = PatientRegistrationDate.find(:first,
      :order => 'registration_date').registration_date

    while (survival_start_date -= 1.year) >= first_registration_date
      survival_end_date   -= 1.year
      date_ranges << {:start_date => survival_start_date,
                      :end_date   => survival_end_date
      }
    end

    survival_analysis_outcomes = Array.new

    date_ranges.each_with_index do |date_range, i|
      outcomes_hash = Hash.new(0)
      all_outcomes = self.outcomes(date_range[:start_date], date_range[:end_date], outcome_end_date, min_age, max_age)

      outcomes_hash["Title"] = "#{(i+1)*12} month survival: outcomes by end of #{outcome_end_date.strftime('%B %Y')}"
      outcomes_hash["Start Date"] = date_range[:start_date]
      outcomes_hash["End Date"] = date_range[:end_date]

      survival_cohort = Reports::CohortByRegistrationDate.new(date_range[:start_date], date_range[:end_date])
      if max_age.nil?
        outcomes_hash["Total"] = survival_cohort.patients_started_on_arv_therapy.length rescue all_outcomes.values.sum
      else
        outcomes_hash["Total"] = all_outcomes.values.sum
      end
      outcomes_hash["Unknown"] = outcomes_hash["Total"] - all_outcomes.values.sum
      outcomes_hash["outcomes"] = all_outcomes

      # if there are no patients registered in that quarter, we must have
      # passed the real date when the clinic opened
      break if outcomes_hash["Total"] == 0
      
      survival_analysis_outcomes << outcomes_hash 
    end
    survival_analysis_outcomes
  end

  def self.cohort(period)
    date_range = Report.generate_cohort_date_range(period)
    start_date = date_range[0] ; end_date = date_range[1]
    cohort = Cohort.new()

    cohort.total_registered = SurvivalAnalysis.report(cohort)
  end



  def self.total_on_pre_art(end_date = Date.today, regimen_ids=[])
     patients = []
     concept_name = ConceptName.find_all_by_name("Pre-art (continue)")
     state = ProgramWorkflowState.find( :first, :conditions => ["concept_id IN (?)",
              concept_name.map{|c|c.concept_id}]).program_workflow_state_id
      PatientProgram.find_by_sql(
					"SELECT p.patient_id FROM patient_program p
          INNER JOIN person pe ON pe.person_id = p.patient_id
          INNER JOIN patient pa ON pe.person_id = pa.patient_id
					WHERE DATE(pa.date_created) <= '#{end_date}'
          AND pa.patient_id NOT IN (#{regimen_ids})
          AND p.program_id = 1
          AND pa.voided = 0").each do | patient |
							patients << patient.patient_id
					end

		return patients

  end

  def self.patient_ids_with_regimens(end_date = @end_date, program_id=nil)
    patient_ids = []
    Observation.find_by_sql("SELECT person_id, order_id FROM obs
                             WHERE  DATE(obs_datetime) <= '#{end_date}'
                             AND order_id IS NOT NULL").each do |patient|
                                    medication = MedicationService.arv(DrugOrder.find(patient.order_id).drug) rescue nil
                                    if  medication == true
                                       patient_ids << patient.person_id
                                    end
                             end
    return patient_ids.uniq
  end

  def self.confirmed_on_pre_art(end_date = Date.today, start_date=nil, regimen_ids=[])
     patients = []
     if start_date
      conditions = "AND earliest_start_date >= '#{start_date}'"
    end
     concept_name = ConceptName.find_all_by_name("Pre-art (continue)")
     state = ProgramWorkflowState.find( :first, :conditions => ["concept_id IN (?)",
              concept_name.map{|c|c.concept_id}]).program_workflow_state_id

     PatientProgram.find_by_sql(
						"SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state, death_date,
					IF(ISNULL(MIN(sdo.value_datetime)), earliest_start_date, MIN(sdo.value_datetime)) AS initiation_date
					FROM earliest_start_date e
					LEFT JOIN start_date_observation sdo ON e.patient_id = sdo.person_id
          LEFT JOIN patient p ON e.patient_id = p.patient_id
					WHERE earliest_start_date <= '#{end_date}' #{conditions}
          AND e.patient_id NOT IN (#{regimen_ids})
          AND p.voided = 0
					GROUP BY e.patient_id
					HAVING state = #{state}").each do | patient |
							patients << patient.patient_id
					end
		return patients

  end
  
  def self.defaulted_patients(end_date, regimen_ids=[])
		patients = []
		PatientProgram.find_by_sql("SELECT e.patient_id, current_defaulter(e.patient_id, '#{end_date}') AS def
											FROM earliest_start_date e LEFT JOIN person p ON p.person_id = e.patient_id
											WHERE e.earliest_start_date <=  '#{end_date}' AND p.dead=0
											HAVING def = 1 AND e.patient_id NOT IN (#{regimen_ids})").each do | patient |
				patients << patient.patient_id
    end
    
		return patients 
	end

  def self.outcomes_total(outcome, end_date=Date.today)
    concept_name = ConceptName.find_all_by_name(outcome)
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
				concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id
		patients = []
		PatientProgram.find_by_sql("SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state
 									FROM earliest_start_date e
									WHERE earliest_start_date <= '#{end_date}'
									HAVING state = #{state}").each do | patient |
			patients << patient.patient_id
		end
		return patients
  end

  def self.exposed_on_pre_art(end_date = Date.today, start_date=nil)
     patients = []
      if start_date
      conditions = "AND earliest_start_date >= '#{start_date}'"
    end
     concept_name = ConceptName.find_all_by_name("Exposed Child (Continue)")
     state = ProgramWorkflowState.find( :first, :conditions => ["concept_id IN (?)", concept_name.map{|c|c.concept_id}]).program_workflow_state_id

     PatientProgram.find_by_sql(
					"SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state, death_date,
					IF(ISNULL(MIN(sdo.value_datetime)), earliest_start_date, MIN(sdo.value_datetime)) AS initiation_date
					FROM earliest_start_date e
					LEFT JOIN start_date_observation sdo ON e.patient_id = sdo.person_id
          LEFT JOIN patient p ON e.patient_id = p.patient_id
					WHERE earliest_start_date <= '#{end_date}' #{conditions}
          AND p.voided = 0
					GROUP BY e.patient_id
					HAVING state = #{state}").each do | patient |
							patients << patient.patient_id
					end
		return patients

  end

  def self.registered(start_date, end_date, regimen_id)
     patients = []
     concept_name = ConceptName.find_all_by_name("Pre-art (continue)")
     state = ProgramWorkflowState.find( :first, :conditions => ["concept_id IN (?)",
              concept_name.map{|c|c.concept_id}]).program_workflow_state_id

    PatientProgram.find_by_sql(
						"SELECT p.patient_id FROM patient_program p
          INNER JOIN person pe ON pe.person_id = p.patient_id
          INNER JOIN patient pa ON pe.person_id = pa.patient_id
					WHERE DATE(pa.date_created) <= '#{end_date}'
          AND DATE(pa.date_created) >= '#{start_date}'
          AND pa.patient_id NOT IN (#{regimen_id})
          AND p.program_id = 1
          AND pa.voided = 0").each do | patient |
							patients << patient.patient_id
					end
=begin
     PatientProgram.find_by_sql(
						"SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state,
					IF(ISNULL(MIN(sdo.value_datetime)), earliest_start_date, MIN(sdo.value_datetime)) AS initiation_date
					FROM earliest_start_date e
					LEFT JOIN start_date_observation sdo ON e.patient_id = sdo.person_id
          LEFT JOIN patient p ON e.patient_id = p.patient_id
					WHERE earliest_start_date >= '#{start_date}'
          AND p.voided = 0
          AND p.patient_id NOT IN (#{regimen_id})
          AND earliest_start_date <= '#{end_date}'
					GROUP BY e.patient_id").each do | patient |
							patients << patient.patient_id
					end
=end
		return patients

  end

  def self.male_total(patient_id)
    return [] if patient_id.blank?
     males = []
    (patient_id || []).each do |patient|
      current_patient = Person.find(patient).gender rescue "Unknown"
      if current_patient.upcase == "M" or current_patient.upcase == "MALE"
        males << patient
      end
    end
    return males
  end

  def self.female_non_pregnant(patient_ids)
    return [] if patient_ids.blank?
    females = []
    (patient_ids || []).each do |patient|
      current_patient = Person.find(patient).gender rescue "Unknown"
      if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        females << patient
      end
    end
		return females
	end

  def self.infants_less_than_2_months(patient_ids)
    return [] if patient_ids.blank?
    infants = []
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"
       unless current_patient == "Unknown"
       current_patient = PatientService.age_in_months(current_patient.person, current_patient.date_created)
      #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        infants << patient if current_patient.to_i < 2
      end
    end
		return infants
	end

  def self.infants_between_2_and_24_months(patient_ids)
    return [] if patient_ids.blank?
    infants = []
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"
       unless current_patient == "Unknown"
       current_patient = PatientService.age_in_months(current_patient.person, current_patient.date_created)
      #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        infants << patient if current_patient.to_i >= 2 and current_patient.to_i < 24
      end
    end
		return infants
	end

  def self.infants_between_24months_and_14_years(patient_ids)
    return [] if patient_ids.blank?
    infants = []
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"
       unless current_patient == "Unknown"
       current_months = PatientService.age_in_months(current_patient.person, current_patient.date_created)
       current_age = PatientService.age(current_patient.person, current_patient.date_created)
      #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        infants << patient if current_months.to_i >= 24 and current_age.to_i <= 14
      end
    end
		return infants
	end

  def self.adults(patient_ids)
    return [] if patient_ids.blank?
    adults = []
    
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"

       unless current_patient == "Unknown"
       current_age = PatientService.age(current_patient.person, current_patient.date_created)
      #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        adults << patient if current_age.to_i > 14
      end
    end
		return adults
	end

  def self.pregnant_women(patient_ids, end_date = Date.today)
    return [] if patient_ids.blank?
     patient_ids = patient_ids.join(",")
     patients = []
    PatientProgram.find_by_sql("SELECT patient_id, earliest_start_date, o.obs_datetime
				FROM earliest_start_date p
					INNER JOIN patient_pregnant_obs o ON p.patient_id = o.person_id
				WHERE earliest_start_date <= '#{end_date}'
          AND p.patient_id IN (#{patient_ids})
					AND DATEDIFF(o.obs_datetime, earliest_start_date) <= 30
					AND DATEDIFF(o.obs_datetime, earliest_start_date) > -1
        GROUP BY patient_id").each do | patient |
			patients << patient.patient_id
		end
    return patients
  end

  def self.patients_initiated_on_pre_art_first_time(patient_ids, end_date, start_date = nil )
    patients = []
    if start_date
      conditions = "AND DATE(obs_datetime) >= '#{start_date}'"
    end
    concept = ConceptName.find_by_name("Ever registered at ART clinic").concept_id
    concept_answer = ConceptName.find_by_name("YES").concept_id

    Observation.find_by_sql("SELECT distinct(person_id) AS patient_id FROM obs
                             WHERE concept_id = #{concept}
                             AND value_coded = #{concept_answer}
                             AND voided = 0
                             AND person_id IN (#{patient_ids})
                             AND DATE(obs_datetime) <= '#{end_date}' #{conditions}").each do | patient |
			patients << patient.patient_id
		end
=begin
    PatientProgram.find_by_sql("SELECT esd.*
      FROM earliest_start_date esd
      LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
      LEFT JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
      WHERE esd.earliest_start_date <= '#{end_date}' #{conditions}
      AND (ero.obs_id IS NULL)
      AND esd.patient_id IN (#{patient_ids})
      GROUP BY esd.patient_id").each do | patient |
			patients << patient.patient_id
		end
=end
    return patients
  end

  def patients_reinitiated_on_pre_art_ever(patient_ids, end_date, start_date = nil )
		patients = []
		Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
			AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ? AND person_id IN ('#{patient_ids}')", ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
				ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
				@end_date.to_date.strftime("%Y-%m-%d")]).each do | patient |
			patients << patient.patient_id
		end
		return patients
	end
end
