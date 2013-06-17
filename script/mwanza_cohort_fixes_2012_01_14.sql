
USE openmrs_mwanza_cohort;

DROP TABLE IF EXISTS `temp_patient_list`;
 
CREATE TABLE `temp_patient_list` (
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `death_date` DATE NOT NULL,
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO temp_patient_list (patient_id, death_date)
SELECT DISTINCT pp.patient_id,
       ps.start_date
    FROM patient_state ps
        INNER JOIN patient_program pp
            ON pp.patient_program_id = ps.patient_program_id AND pp.program_id = 1
    WHERE ps.state = 3 AND ps.voided = 0;

UPDATE person p
SET dead =1, death_date = (select death_date from temp_patient_list where patient_id =  p.person_id limit 1)
WHERE p.person_id in (select distinct patient_id from temp_patient_list);

DROP TABLE IF EXISTS `temp_patient_list`;
