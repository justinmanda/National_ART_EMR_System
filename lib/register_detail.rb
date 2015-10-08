class RegisterDetail
  # class that wraps a complete sql for art register
  def self.patient_details
    date = Date.today.to_s
    details = Person.find_by_sql("SELECT p.person_id,patient_identifier(p.person_id) AS arv_no,pn.given_name,pn.family_name,p.gender as Sex,
                                      (DATE_FORMAT(SYSDATE(),'%Y') - DATE_FORMAT(p.birthdate,'%Y')) as Age,
                                       reason_for_starting(p.person_id) as reason_for_starting,
                                       DATE_FORMAT(pr.date_enrolled,'%Y-%m-%d') as Registration_date,
                                       patient_outcome(p.person_id,'#{date}') as outcome,
                                       patient_outcome_date(p.person_id,'#{date}') as outcome_date,at.value  AS occupation,
                                       patient_regimen(p.person_id,'#{date}') as Regimen
                                       FROM person p
                                       INNER JOIN person_address ad ON p.person_id = ad.person_id
                                       INNER JOIN earliest_start_date est ON p.person_id = est.patient_id
                                       INNER JOIN patient_program pr ON p.person_id = pr.patient_id
                                       INNER JOIN person_name pn ON p.person_id = pn.person_id
                                       INNER JOIN person_attribute at ON p.person_id = at.person_id
                                       WHERE pr.program_id = 1 AND
                                       at.person_attribute_type_id = 13 AND pr.voided = 0")
    return details

  end
end