


def start
  User.current = User.find(1)

  (get_patients || []).each do |person_id|
    person = Person.find(person_id) rescue nil
    next if person.blank?
    person.void("Patient had no name and ARV number")
    puts "voided: #{person_id}"
  end
end


def get_patients
  patients = []
  
  PatientIdentifier.find_by_sql("
SELECT p.person_id person_id FROM person_name n 
INNER JOIN encounter e ON e.patient_id = n.person_id 
AND e.voided = 0 AND n.voided = 0 AND e.encounter_type IN(
SELECT encounter_type_id FROM encounter_type 
WHERE name IN('HIV CLINIC REGISTRATION','HIV RECEPTION','VITALS',         
'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING'))
INNER JOIN person p ON p.person_id = e.patient_id
AND p.voided = 0
WHERE n.given_name IS NULL AND n.family_name IS NULL
GROUP BY n.person_id
ORDER BY birthdate,gender
").map do |record|
    patients << record.person_id
  end

  PatientIdentifier.find_by_sql("
SELECT p.person_id person_id FROM person_name n 
INNER JOIN encounter e ON e.patient_id = n.person_id 
AND e.voided = 0 AND n.voided = 0 AND e.encounter_type IN(
SELECT encounter_type_id FROM encounter_type 
WHERE name IN('HIV CLINIC REGISTRATION','HIV RECEPTION','VITALS',         
'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING'))
INNER JOIN person p ON p.person_id = e.patient_id
AND p.voided = 0
INNER JOIN patient_identifier i ON i.patient_id = e.patient_id
AND i.identifier_type = 4 AND i.voided = 0
WHERE n.given_name IS NULL AND n.family_name IS NULL
GROUP BY n.person_id
ORDER BY birthdate,gender
").map do |record|
    patients.delete(record.person_id)
  end

  return patients
end







start
