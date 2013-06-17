UPDATE obs
    SET value_coded_name_id =   CASE value_text
                                WHEN "1066" THEN 1103 -- No
                                WHEN "1067" THEN 1104 -- Unknown
                                WHEN "1065" THEN 1102 -- Yes 
                                END ,
    value_coded = value_text,
    value_text = NULL
WHERE concept_id = 2552 AND value_text IS NOT NULL;



