
def regimens
  concept = ConceptName.find_by_name("Regimen Category").concept_id
  obs = Observation.find_by_sql("
                              SELECT person_id, order_id, DATE(obs_datetime) AS obs_datetime, o.encounter_id FROM obs o
                              INNER JOIN encounter e USING (encounter_id)
                              INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
                              INNER JOIN earliest_start_date s ON o.person_id = s.patient_id
                              WHERE e.encounter_id NOT IN
                              (SELECT DISTINCT encounter_id FROM obs
                              WHERE concept_id = #{concept}
                              AND voided = 0
                              AND encounter_id IN (SELECT encounter_id FROM encounter
                              WHERE encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'DISPENSING') AND voided = 0))
                              AND et.name = 'DISPENSING'
                              AND e.voided = 0
                              AND o.voided = 0
                              AND o.order_id IS NOT NULL
                              AND s.death_date IS NULL")
  x = 0
  obs.each{|dispensed|
     order = DrugOrder.find(dispensed.order_id).drug
     person = Person.find(dispensed.person_id)
     date = dispensed.obs_datetime
     encounter = dispensed.encounter_id

     index = DrugOrder.find_by_sql("
                              SELECT re.regimen_index FROM drug_order o
                              INNER JOIN regimen_drug_order r ON r.drug_inventory_id = o.drug_inventory_id
                              INNER JOIN regimen re ON re.regimen_id = r.regimen_id
                              WHERE o.order_id = #{dispensed.order_id}
                                    AND r.voided = 0
                                    AND re.regimen_index != 0
                                    AND re.regimen_index IS NOT NULL")
    unless index.blank?
        written = Observation.find(:all,
                  :conditions => ['person_id = ? AND concept_id = ? AND encounter_id = ? AND DATE(obs_datetime) = ?',
                  dispensed.person_id, concept,encounter, date.to_date.strftime('%Y-%m-%d') ])
              if written.blank?
                category = Observation.new
                category.concept_id = concept
                category.person_id = person.person_id
                category.encounter_id = encounter
                category.location_id = 700
                category.value_text = index.first.regimen_index
                category.creator = 1
                category.obs_datetime = date.to_date.strftime('%Y-%m-%d 00:00:00')
                category.save
                
                x = x + 1
                puts "#{person.person_id} :::: #{date.to_date.strftime('%Y-%m-%d')}"
              end
    end

     
  }
  puts "Written #{x} out of #{obs.length}"
end

regimens
