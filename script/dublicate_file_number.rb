def file_number
 puts "Search started at #{Time.now}"
 duplicate = PatientIdentifier.find_by_sql("SELECT DISTINCT(patient_id) FROM patient_identifier i
            join (SELECT identifier FROM patient_identifier WHERE voided = 0
            AND identifier_type = 17 GROUP BY identifier
            HAVING COUNT(identifier) > 1 ) AS available ON available.identifier = i.identifier
            WHERE i.voided = 0 ORDER BY patient_id")

 puts "Found #{duplicate.length} patients with duplicate file numbers ..."

 duplicate.each{|file|
    puts "cleaning patient #{file.patient_id}"
    identifier = PatientIdentifier.find(:all, :conditions => ["patient_id = ? AND identifier_type = 17", file.patient_id])
    clean = identifier.last.patient_identifier_id
    identifier.each{|voiding|
      if voiding.patient_identifier_id != clean
        voiding.voided = 1
        voiding.save
        puts "Voided identifier #{voiding.patient_identifier_id}"
      end
    }
   
}

end

file_number
