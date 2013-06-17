USE openmrs_mpc;

DROP TABLE IF EXISTS `temp_states_list`;

CREATE TABLE `temp_states_list` (
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `state` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `creator` int(11) NOT NULL DEFAULT '0',
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO temp_states_list (patient_id, state, start_date, date_created, location_id, creator)
SELECT patient_id,
    CASE value_coded
    WHEN 322 THEN 3     -- patient died
    WHEN 386 THEN 6     -- treatment stopped
    WHEN 325 THEN 2     -- Trasnfered out 
    WHEN 374 THEN 2     -- Trasnfered out (with note)
    WHEN 383 THEN 2     -- Trasnfered out (without note)
    END AS state,
    obs_datetime,
    date_created,
    location_id,
    creator
FROM mpc_bart1.obs
WHERE concept_id = 28 
    AND value_coded IS NOT NULL 
    AND voided = 0
    AND value_coded IN (322, 386, 325, 374, 383);