-- Getting states from bart1 for creating exit from care encounters in bart2

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

-- Agrees to follow up script [Move value_text to value_coded and value_coded_name_id]

UPDATE obs
    SET value_coded_name_id =   CASE value_text
                                WHEN "1066" THEN 1103 -- No
                                WHEN "1067" THEN 1104 -- Unknown
                                WHEN "1065" THEN 1102 -- Yes 
                                END ,
    value_coded = value_text,
    value_text = NULL
WHERE concept_id = 2552 AND value_text IS NOT NULL;

-- Move value_text to Value_Datetime for Date Arv Started observation

UPDATE obs
    SET value_datetime = value_text
WHERE concept_id = 2516 AND value_text IS NOT NULL AND value_datetime IS NULL;

-- Fix Drug Orders with zero quantity

DROP TABLE IF EXISTS `temp_orders_list`;

CREATE TABLE `temp_orders_list` (
  `drug_order_id` int(11) NOT NULL DEFAULT '0',
  `drug` int(11) NOT NULL DEFAULT '0',
  `quantity` int NOT NULL DEFAULT '0',
  KEY (`drug_order_id`),
  KEY (`drug`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO temp_orders_list (drug_order_id, drug, quantity)
SELECT do.order_id, do.drug_inventory_id, SUM(ob.value_numeric)
-- select do.*, ob.value_drug, ob.value_numeric, ob.order_id
    FROM drug_order do 
        INNER JOIN orders o ON o.order_id = do.order_id AND o.voided = 0
        INNER JOIN obs ob ON do.order_id = ob.order_id AND ob.value_drug = do.drug_inventory_id AND ob.voided = 0
    WHERE quantity IS NULL AND ob.value_numeric <> 0
GROUP BY ob.order_id, ob.value_drug;

update drug_order
set quantity = (select quantity from temp_orders_list where drug_order_id = order_id and drug = drug_inventory_id) 
where order_id in (select drug_order_id from temp_orders_list);

-- Once this is done, please run create exit from care 

