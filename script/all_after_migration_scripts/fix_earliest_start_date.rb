=begin

Creator : Precious Ulemu Bondwe
Date    : 2013-08-28 
Purpose : To add the pills brought back to the clinic to a particular drug order to 
          help with the adherence calculation. This script has been developed for the 
          data migration process. 
Modifications:
  initials - date - description

=end

def start

  hiv_prog = Program.find_by_name("HIV Program").program_id
  art_patients = PatientProgram.find_by_sql("SELECT distinct patient_id, patient_program_id from patient_program where program_id = #{hiv_prog} and voided = 0")

  (art_patients || []).each do |patient|

    enrolled_date = date_antiretrovirals_started(patient.patient)

    first_dispense = get_first_dispensation(patient.patient_id)


    unless first_dispense.blank?
      if enrolled_date != first_dispense
        puts "change dates"
        correct_start_date = first_dispense.strftime('%Y-%m-%d 00:00:00')

				latest_program =	PatientProgram.find(:first, :conditions => ["patient_id = ? and program_id = ? and voided = ?", patient.patient_id, 1, 0]).id
				last_state = PatientState.find(:first, :conditions => ["patient_program_id = ? and state = ?", latest_program, 7]).patient_state_id rescue nil

			unless last_state.blank?
			
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program
SET date_enrolled = '#{first_dispense.strftime('%Y-%m-%d 00:00:00')}'
WHERE patient_program_id = #{latest_program}
EOF

        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_state
SET start_date = '#{correct_start_date.to_date.strftime('%Y-%m-%d 00:00:00')}',
date_created = '#{correct_start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
WHERE patient_state_id = #{last_state}
EOF

				end
				enrolled_date = enrolled_date.to_date if !enrolled_date.blank?
				correct_start_date = correct_start_date.to_date if !correct_start_date.blank?
        puts">>>>>>>#{patient.patient_id}....From: #{enrolled_date}......To: #{correct_start_date.to_date}........."
      end


    end

end

end

def get_first_dispensation(patient_id)

  arv_drug_concepts =  MedicationService.arv_drugs.collect{|x| x.concept_id}

  arv_drugs = Drug.find(:all, :conditions => ["concept_id in (?)", arv_drug_concepts]).collect{|x| x.drug_id}

  dispense_conc = Concept.find_by_name("Amount Dispensed").concept_id
  dispense_obs = Observation.find_by_sql("SELECT min(obs_datetime) as obs_datetime from obs where person_id = #{patient_id}
                                        AND concept_id = #{dispense_conc} and value_drug in (#{arv_drugs.join(',')})")


  return dispense_obs.first.obs_datetime rescue nil

end

def date_antiretrovirals_started(patient)
  concept_id = ConceptName.find_by_name('ART START DATE').concept_id
  start_date = Observation.find(:first, :conditions => ["concept_id = ? AND
    person_id = ?", concept_id, patient.id]).value_datetime rescue ""

  if start_date.blank? || start_date == ""
    concept_id = ConceptName.find_by_name('Date antiretrovirals started').concept_id
    start_date = Observation.find(:first, :conditions => ["concept_id = ? AND
      person_id = ?", concept_id, patient.id]).value_text rescue ""
    art_start_date = start_date
    if art_start_date.blank? || art_start_date == ""
      start_date = ActiveRecord::Base.connection.select_value "
        SELECT earliest_start_date FROM earliest_start_date
        WHERE patient_id = #{patient.id} LIMIT 1"
    end
  end

  start_date.to_date rescue nil
end

start
