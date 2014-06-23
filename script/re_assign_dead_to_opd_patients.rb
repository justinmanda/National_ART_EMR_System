
def patients_fix

   patients = Patient.find_by_sql("
                              SELECT DISTINCT p.patient_id, ps.start_date FROM patient p
                              INNER join earliest_start_date e ON e.patient_id = p.patient_id
                              INNER JOIN obs o ON o.person_id = e.patient_id
                              INNER JOIN patient_program pp ON pp.patient_id = e.patient_id
                              INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id
                              WHERE o.voided = 0
                              AND e.death_date IS NULL
                              AND DATE(o.obs_datetime) > DATE(ps.start_date)
                              AND pp.voided = 0
                              AND pp.program_id = 1
                              AND ps.voided = 0
                              AND ps.state = 3")

  puts "#{patients.length} To be affected"
   x = 0
  patients.each {|patient|
    person = Person.find(patient.patient_id)
    arv_number = PatientService.get_patient(person).arv_number rescue ""
    death_date = patient.start_date
    person.dead = 1
    person.death_date = death_date
    person.save

  
    encounters_after_death = Encounter.find_by_sql("
                            SELECT * FROM encounter
                            WHERE encounter_type IN (SELECT encounter_type_id
                            FROM encounter_type
                            WHERE name IN ('HIV CLINIC REGISTRATION','HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING'))
                            AND patient_id = #{patient.patient_id}
                            AND DATE(encounter_datetime) > '#{death_date}'
                            AND voided = 0")
    unless encounters_after_death.blank?
       x = x + 1
       puts "Patient id >> #{patient.patient_id} ARV number #{arv_number}"
       person.dead = 0
       person.death_date = nil
       person.save      
    end
  }
  puts "Number of patients observations after death #{patients.length}"
  puts "ART patients visiting after death #{x}"

end

patients_fix