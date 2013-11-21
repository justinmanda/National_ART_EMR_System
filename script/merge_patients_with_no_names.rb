


def start
  User.current = User.find(1)

  (get_patients || []).each do |primary_patient, secondary_patient, arv_number|
    p1 = Patient.find(primary_patient) rescue nil
    p2 = Patient.find(secondary_patient) rescue nil
    next if p1.blank? or p2.blank?

    Patient.merge(primary_patient, secondary_patient)
    number = PatientIdentifier.find(:first,:conditions => ["patient_id = ? 
      AND identifier_type = 4",primary_patient])

    if number.blank?
      old_arv_number = PatientIdentifier.find(:first,
        :conditions => ["patient_id = ? AND identifier_type = 2
      AND identifier = ?",primary_patient,arv_number])
      if not old_arv_number.blank?
        old_arv_number.identifier_type = 4
        old_arv_number.save
      else
        old_arv_number = PatientIdentifier.new
        old_arv_number.identifier = arv_number
        old_arv_number.identifier_type = 4
        old_arv_number.patient_id = primary_patient
        old_arv_number.save
      end
    end
    puts "merged: #{secondary_patient} with #{primary_patient}"
  end
end


def get_patients
  patients = []
  
  PatientIdentifier.find_by_sql("
SELECT t2.patient_id primary_patient, t.patient_id secondary_patient, t.identifier arv_number
FROM openmrs_kawale.patient_identifier t
INNER JOIN openmrs_kawale.patient_identifier t2 
ON t.identifier = t2.identifier AND t.voided = 0 AND t2.voided = 0
WHERE t.identifier_type = 4 AND t2.identifier_type = 3
AND (t.patient_id <> t2.patient_id)
").map do |record|
    patients << [record.primary_patient, record.secondary_patient, record.arv_number]
  end

  PatientIdentifier.find_by_sql("
SELECT t2.patient_id primary_patient, t.patient_id secondary_patient, t.identifier arv_number
FROM openmrs_kawale.patient_identifier t
INNER JOIN openmrs_kawale.patient_identifier t2 
ON t.identifier = t2.identifier AND t.voided = 0 AND t2.voided = 0
WHERE t.identifier_type = 4 AND t2.identifier_type = 2
AND (t.patient_id <> t2.patient_id)
").map do |record|
    patients << [record.primary_patient, record.secondary_patient, record.arv_number]
  end

  return patients
end







start
