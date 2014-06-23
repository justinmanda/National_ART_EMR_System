
#LowerLimit = 43
#UpperLimit	= 46
	
		
def load_data
	
	patients = get_art_patients
	count = patients.length
	puts "Number of patients to be initialized: #{patients.length}"
  return if patients.blank?
  
  puts Date.today
	patients.each do |patient|
		puts "working on patient_id: #{patient.patient_id}......#{count} patients to go "
		orders = []
		drug_orders = []	
    Patient.find_by_sql("UPDATE patient SET voided = 0 WHERE patient_id = #{patient.id}") rescue nil

		load_states(patient.id)
    patient_orders = Order.find(:all,:joins =>"INNER JOIN encounter e 
      ON e.encounter_id = orders.encounter_id AND e.patient_id = #{patient.id}")

		(patient_orders || []).each do |order|
			orders << order
			drug_orders << order.drug_order unless order.drug_order.blank?
		end

		load_orders(orders)			
		load_drug_orders(drug_orders)
		load_patient_identifiers(patient.id)	
		load_observations(patient.id)
		load_orders1(orders)			
		load_drug_orders1(drug_orders)
		count -=1	
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
  #raise orders.to_yaml
	#puts "Loading orders. #{orders.length} orders"
  order_ids = []
	orders.each do |order|
		#puts "#{order.order_id}"
    order_ids << order.order_id
	end		

	if !order_ids.blank?
	 order_ids.each do |order|
	 #puts "#{order}"
    ActiveRecord::Base.connection.execute <<EOF
      UPDATE orders SET voided = 0 WHERE order_id = #{order};
EOF
   end
  end
		
end

def	load_drug_orders(drug_orders)

	#puts "#{drug_orders.length} drug order sets"
  drug_order_ids = []
	drug_orders.each do |drug_order|
    drug_order_ids << drug_order.id
	end		
  	
  if !drug_order_ids.blank?
    drug_order_ids.each do |drug_order|
      	 #puts "#{drug_order}"
      ActiveRecord::Base.connection.execute <<EOF
        UPDATE drug_order SET complex = 0 WHERE order_id = #{drug_order};
EOF
    end
  end
end

def load_orders1(orders)
  #raise orders.to_yaml
	#puts "Loading orders. #{orders.length} orders"
  order_ids = []
	orders.each do |order|
		#puts "#{order.order_id}"
    order_ids << order.order_id
	end		

	if !order_ids.blank?
	 order_ids.each do |order|

    ActiveRecord::Base.connection.execute <<EOF
      UPDATE orders SET voided = 0 WHERE order_id = #{order};
EOF
   end
  end
		
end

def	load_drug_orders1(drug_orders)

	#puts "#{drug_orders.length} drug order sets"
  drug_order_ids = []
	drug_orders.each do |drug_order|
    drug_order_ids << drug_order.id
	end		
  	
  if !drug_order_ids.blank?
    drug_order_ids.each do |drug_order|
      ActiveRecord::Base.connection.execute <<EOF
        UPDATE drug_order SET complex = 0 WHERE order_id = #{drug_order};
EOF
    end
  end
end

def load_patient_identifiers(patient_id)

  ActiveRecord::Base.connection.execute <<EOF
    UPDATE patient_identifier SET voided = 0 WHERE patient_id = #{patient_id};                      
EOF

end

def load_observations(person_id)

	observations = Observation.find(:all, :conditions => ["person_id = #{person_id}"])
  obs_ids = observations.map(&:obs_id) rescue nil
  next if obs_ids.blank?

  #obs_ids.each do |obs|
    ActiveRecord::Base.connection.execute <<EOF
      UPDATE obs SET voided = 0 WHERE obs_id IN (#{obs_ids.join(',')});
EOF
#end
                                                            
end

def get_art_patients         
  art_encounters = ['HIV CLINIC REGISTRATION','HIV RECEPTION','VITALS',
    'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING']
                                                                                
  encounter_type = EncounterType.find(:all,:conditions =>["name IN(?)",art_encounters]).map(&:id)
                                                                       
  Patient.find(:all,:joins =>"INNER JOIN encounter e                            
    ON e.patient_id = patient.patient_id AND e.voided = 0",                     
    :conditions =>["encounter_type IN (?)",encounter_type], 
    :group => "patient.patient_id")                                             
end

load_data
