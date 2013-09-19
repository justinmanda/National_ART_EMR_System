
#LowerLimit = 43
#UpperLimit	= 46

def get_art_drug_given_date(patient_id, date)                    
  clinic_encounters  =  ['DISPENSING']                                        
  encounter_type_ids = EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}
  end_date = date.strftime('%Y-%m-%d 23:59:59')              
  concept_id = Concept.find_by_name('AMOUNT DISPENSED').id                    

  orders = Order.find(:all,:joins =>"INNER JOIN obs ON obs.order_id = orders.order_id",
      :conditions =>["obs.person_id = ? AND obs.concept_id = ? AND obs_datetime <= ?",                             
      patient_id,concept_id, end_date],:order =>"obs_datetime")                                                
  
  encounter_dates = []
                                                                            
  (orders || []).each do |order|                                            
    drug = order.drug_order.drug                                              
    next if not MedicationService.arv(drug)                                              
    encounter_dates << order.encounter.encounter_datetime.to_date
  end                                                            

  return [encounter_dates.sort[0], encounter_dates.sort[-1]] unless encounter_dates.blank?
  return []
end

def get_dates(patient_id)
  art_encounters = ['HIV CLINIC REGISTRATION','HIV RECEPTION','VITALS',         
    'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING']
                                                                                
  encounter_type = EncounterType.find(:all,:conditions =>["name IN(?)",art_encounters]).map(&:id)
  encounter_dates = []
                                    
  Encounter.find(:all,:conditions =>["encounter_type IN (?)
    AND patient_id = ?", encounter_type,patient_id]).each do |e|
    encounter_dates << e.encounter_datetime.to_date
  end

  return [encounter_dates.sort[0],encounter_dates.sort[-1]]
end

def get_hiv_encounter_dates(patient_id)
  encounter_type = EncounterType.find_by_name('HIV STAGING').id
  encounter_dates = []
                                    
  Encounter.find(:all,:conditions =>["encounter_type = (?) AND voided = 0
  AND patient_id = ?",encounter_type, patient_id]).each do |e|
      encounter_dates << e.encounter_datetime.to_date
  end

  return encounter_dates
end


def get_art_adherence_date(patient_id)
  encounter_type = EncounterType.find_by_name('ART ADHERENCE').id
  encounter_dates = []
                                    
  Encounter.find(:all,:conditions =>["encounter_type = (?) AND voided = 0
  AND patient_id = ?",encounter_type, patient_id]).each do |e|
      encounter_dates << e.encounter_datetime.to_date
  end

  return encounter_dates.sort[-1] rescue []
end

def load_data
	
	patients = get_art_patients
	count = patients.length
	puts "Number of patients to be initialized: #{patients.length}"
  return if patients.blank?
	
	patients.each_with_index do |patient, i|
		puts "Record: #{i+1} of #{count}"
    start_date , end_date = get_dates(patient.id)
    hiv_encounter_dates = get_hiv_encounter_dates(patient.id)
    art_drug_given_dates = get_art_drug_given_date(patient.id , end_date)
    art_adherence_date = get_art_adherence_date(patient.id)

		orders = []
		drug_orders = []	
    Patient.find_by_sql("UPDATE patient SET voided = 0 WHERE patient_id = #{patient.id}") rescue nil

		load_states(patient.id)

    patient_orders = []
    
    dates = [start_date,end_date]

    unless hiv_encounter_dates.blank?
      dates = (dates + hiv_encounter_dates).uniq
    end

    unless art_drug_given_dates.blank?
      dates = (dates << art_drug_given_dates[0]).uniq
      dates = (dates << art_drug_given_dates[1]).uniq
    end

    unless art_adherence_date.blank?
      dates = (dates << art_adherence_date).uniq
    end

    dates.each do |d|
      Order.find(:all,:joins =>"INNER JOIN encounter e 
        ON e.encounter_id = orders.encounter_id 
        AND e.encounter_datetime BETWEEN '#{d.strftime('%Y-%m-%d 00:00:00')}'
        AND '#{d.strftime('%Y-%m-%d 23:59:59')}' 
        AND e.patient_id = #{patient.id}").each do |order|
        patient_orders << order
      end
    end


		(patient_orders || []).each do |order|
			orders << order
			drug_orders << order.drug_order unless order.drug_order.blank?
		end
		
		load_orders(orders)			
		load_drug_orders(drug_orders)
		load_patient_identifiers(patient.id)	
		load_observations(patient.id, dates)
	end

end

def load_states(patient_id)
	
	programs = PatientProgram.find_by_patient_id(patient_id)
	

	
		states = programs.patient_states rescue return
		
		states.each do |patient_state|
		
			patient_state.voided = patient_state.voided 
			patient_state.save!
			
		end
		

	
end

def load_orders(orders)

	#puts "Loading orders. #{orders.length} orders"
  order_ids = []
	orders.each do |order|
    order_ids << order.id
	end		
	
	if !order_ids.blank?
    ActiveRecord::Base.connection.execute <<EOF
      UPDATE orders SET voided = 0 WHERE order_id IN(#{order_ids.join(',')});
EOF
   end
		
end

def	load_drug_orders(drug_orders)

	#puts "#{drug_orders.length} drug order sets"
  drug_order_ids = []
	drug_orders.each do |drug_order|
    drug_order_ids << drug_order.id
	end		
  	
  if !drug_order_ids.blank?
    ActiveRecord::Base.connection.execute <<EOF
      UPDATE drug_order SET complex = 0 WHERE order_id IN(#{drug_order_ids.join(',')});
EOF
  end
end

def load_patient_identifiers(patient_id)

  ActiveRecord::Base.connection.execute <<EOF
    UPDATE patient_identifier SET voided = 0 WHERE patient_id = #{patient_id};                      
EOF

end

def load_observations(person_id, dates)

	observations = []
  
  dates.each do |d|
    Observation.find(:all, 
      :conditions => ["person_id = #{person_id} 
      AND obs_datetime >= '#{d.strftime('%Y-%m-%d 00:00:00')}'
      AND obs_datetime <= '#{d.strftime('%Y-%m-%d 23:59:59')}'"]).each do |ob|
      observations << ob
    end
  end

  obs_ids = observations.map(&:obs_id).join(',') rescue nil
  next if obs_ids.blank?
                                                                                
  ActiveRecord::Base.connection.execute <<EOF                                 
    UPDATE obs SET voided = 0 WHERE obs_id IN (#{obs_ids});
EOF
                                                                                
                                                                                
end

def get_art_patients                                                            
  art_encounters = ['HIV CLINIC REGISTRATION','HIV RECEPTION',         
    'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE']
                                                                                
  encounter_type = EncounterType.find(:all,:conditions =>["name IN(?)",art_encounters]).map(&:id)
                                                                                
  Patient.find(:all,:joins =>"INNER JOIN encounter e                            
    ON e.patient_id = patient.patient_id AND e.voided = 0",                     
    :conditions =>["encounter_type IN (?)",encounter_type], 
    :group => "patient.patient_id")                                             
end

load_data
