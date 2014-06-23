def init_variables
  #set Location first
  site_id = GlobalProperty.find_by_property('current_health_center_id').property_value

	location = Location.find(site_id)
	Location.current_location = location
end

def start
  init_variables
  @location = Encounter.find(:first, :conditions => ["location_id IS NOT NULL"], :limit => 1).location_id

  Location.current_location = Location.find(@location)

  User.current = User.find(1)

  start_date = Date.today.strftime('%Y-%m-%d 23:59:59')

  amount_brought_concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
  adherence_concept_id = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
  adherence_encounter_id = EncounterType.find_by_name("ART ADHERENCE").id
  dispense_concept_id = ConceptName.find_by_name("Amount dispensed").concept_id

  records = DrugOrder.find_by_sql("SELECT t3.person_id person_id,
    t1.drug_inventory_id drug_id,DATE(t3.obs_datetime) visit_date, t1.order_id
    FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id 
    INNER JOIN obs t3 ON t3.order_id = t2.order_id 
    WHERE t3.concept_id = #{amount_brought_concept_id} 
    AND t3.obs_datetime <= '#{start_date}' AND t2.concept_id <> 916 GROUP BY t3.person_id,
    obs_datetime,t3.obs_id").collect do |record|
      [record.person_id,record.drug_id,record.visit_date, record.order_id]
    end

  (records || []).each do |record|
    adherence = ActiveRecord::Base.connection.select_value <<EOF                   
      SELECT adherence_cal(#{record[0]},#{record[1]},'#{record[2]}');                                         
EOF
                                                       
    adherence = adherence.to_i rescue nil
    
    adherence_to_show = 0
    adherence_over_100 = 0
    adherence_below_100 = 0
    over_100_done = false
    below_100_done = false

      drug_adherence = adherence
      if drug_adherence <= 100
        adherence_below_100 = adherence.to_i if adherence_below_100 == 0
        adherence_below_100 = adherence.to_i if drug_adherence <= adherence_below_100
        below_100_done = true
      else  
        adherence_over_100 = adherence.to_i if adherence_over_100 == 0
        adherence_over_100 = adherence.to_i if drug_adherence >= adherence_over_100
        over_100_done = true
      end 

    return if !over_100_done and !below_100_done
    over_100 = 0
    below_100 = 0
    over_100 = adherence_over_100 - 100 if over_100_done
    below_100 = 100 - adherence_below_100 if below_100_done

    if over_100 >= below_100 and over_100_done
      adherence = 100 - (adherence_over_100 - 100)
    else
      adherence = adherence_below_100
    end
    
    puts "#{record[0]},#{record[1]},#{record[2]} ============ #{adherence}"                                         

    Encounter.transaction do 
      adherence_encounter = Encounter.new
      adherence_encounter.encounter_type = adherence_encounter_id
      adherence_encounter.patient_id = record[0]
      adherence_encounter.location_id = Location.current_location.id
      adherence_encounter.encounter_datetime = record[2].to_date.strftime('%Y-%m-%d 00:00:02')
      if adherence_encounter.save
        obs = Observation.new()
        obs.concept_id = adherence_concept_id
        obs.encounter_id = adherence_encounter.id
        obs.person_id = adherence_encounter.patient_id
        obs.location_id = Location.current_location.id
        obs.obs_datetime = adherence_encounter.encounter_datetime
        obs.value_text = adherence
        obs.order_id = record[3]
        obs.save
				#last_dispense = Observation.find(:last,:conditions => ["concept_id =? AND person_id = ? AND obs_datetime < ? AND value_drug = ?",
				#dispense_concept_id, adherence_encounter.patient_id,adherence_encounter.encounter_datetime,record[1]], 
				#:order => "obs_datetime DESC")
				#last_dispense.encounter_id = adherence_encounter.encounter_id
				#last_dispense.save
      end
    end
    puts "............... count #{adherence}"
  end

end


start
