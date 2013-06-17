

def start
  Location.current_location = Location.find(177)
  User.current = User.find(1)

  start_date = Date.today.strftime('%Y-%m-%d 23:59:59')

  amount_brought_concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
  adherence_concept_id = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
  adherence_encounter_id = EncounterType.find_by_name("ART ADHERENCE").id
  dispense_concept_id = ConceptName.find_by_name("Amount dispensed").concept_id


  records = DrugOrder.find_by_sql("SELECT t3.person_id person_id,
    t1.drug_inventory_id drug_id,DATE(t3.obs_datetime) visit_date
    FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id 
    INNER JOIN obs t3 ON t3.order_id = t2.order_id 
    WHERE t3.concept_id = #{amount_brought_concept_id} 
    AND t3.obs_datetime <= '#{start_date}' GROUP BY t3.person_id,
    obs_datetime,t3.obs_id").collect do |record|
      [record.person_id,record.drug_id,record.visit_date]
    end

  (records || []).each do |record|
    adherence = ActiveRecord::Base.connection.select_value <<EOF                   
      SELECT adherence_cal(#{record[0]},#{record[1]},'#{record[2]}');                                         
EOF
                                                       
    adherence = adherence.to_i rescue nil
    puts "#{record[0]},#{record[1]},#{record[2]} ============ #{adherence}"                                         

    Encounter.transaction do 
      adherence_encounter = Encounter.new
      adherence_encounter.encounter_type = adherence_encounter_id
      adherence_encounter.patient_id = record[0]
      adherence_encounter.encounter_datetime = record[2].to_date.strftime('%Y-%m-%d 00:00:02')
      if adherence_encounter.save
        obs = Observation.new()
        obs.concept_id = adherence_concept_id
        obs.encounter_id = adherence_encounter.id
        obs.person_id = adherence_encounter.patient_id
        obs.obs_datetime = adherence_encounter.encounter_datetime
        obs.value_text = adherence
        obs.save
				last_dispense = Observation.find(:last,:conditions => ["concept_id =? AND person_id = ? AND obs_datetime < ? AND value_drug = ?",
				dispense_concept_id, adherence_encounter.patient_id,adherence_encounter.encounter_datetime,record[1]], 
				:order => "obs_datetime DESC")
				last_dispense.encounter_id = adherence_encounter.encounter_id
				last_dispense.save!
      end
    end
    puts "............... count #{adherence}"
  end

end


start
