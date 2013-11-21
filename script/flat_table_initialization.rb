
def load_patients
  start_time = Time.now()
  puts "started at: #{start_time.strftime('%Y-%m-%d %H:%M:%S')}"
	patients = get_art_patients
	orders = []
	drug_orders = []
	
	puts "Loading patients. Total number of patients: #{patients.length}"
  return if patients.blank?

	patients.each do |patient|
    Patient.find_by_sql("UPDATE patient SET voided = 0 WHERE patient_id = #{patient.id}") rescue nil	

		patient.encounters.each do |enc|
			orders << enc.orders
			drug_orders << enc.drug_orders
		end
	
	end

	load_states()	
	load_observations
	load_orders(orders)			
	load_drug_orders(drug_orders)
	load_patient_identifiers
	
  puts "ended at: #{Time.now().strftime('%Y-%m-%d %H:%M:%S')}"
end

def load_states

	patient_states = PatientState.all
	
	puts "Loading patient states. Total state records #{patient_states.length}"
	patient_states.each do |patient_state|
	
		patient_state.voided = patient_state.voided 
		patient_state.save!
		
	end	
end

def load_observations
	
	obs_count = Observation.count

	puts "Loading observations. Total number of observations #{obs_count}"

	lower_limit = 0
	upper_limit = 1000
	
	while lower_limit <= obs_count
	
		observations = Observation.find_by_sql("SELECT * FROM obs WHERE obs_id BETWEEN #{lower_limit} AND #{upper_limit} AND VOIDED = 0  ")
	  obs_ids = observations.map(&:obs_id).join(',') rescue nil
    next if obs_ids.blank?		
		
    ActiveRecord::Base.connection.execute <<EOF
    UPDATE obs SET voided = 0 WHERE obs_id IN(#{obs_ids});
EOF

		
		lower_limit +=1000
		upper_limit +=1000	
				
	end

	#Observation.find_by_sql("UPDATE obs SET voided = 0 WHERE voided = 5 ") rescue nil	

	
end

def load_orders(orders)

	puts "Loading orders. #{orders.length} orders"
	orders.each do |orders_set|

		orders_set.each do |order|
			order.voided = 5		
			order.save!	
		end
	end		
	
	Order.find_by_sql("UPDATE orders SET voided = 0 WHERE voided = 5") rescue nil
		
end

def	load_drug_orders(drug_orders)

	puts "#{drug_orders.length} drug order sets"
	drug_orders.each do |drug_order_set|
		drug_order_set.each do |drug_order|
			drug_order.complex = 99		
			drug_order.save!
		end
	end		
	
	DrugOrder.find_by_sql("UPDATE drug_order SET complex = 0 WHERE complex = 99") rescue nil

end

def load_patient_identifiers

		identifiers = PatientIdentifier.all
		puts "Total identifiers #{identifiers.length}"
		identifiers.each do |identifier|
		
			identifier.voided = 5
			identifier.save!
		
		end
	
		PatientIdentifier.find_by_sql("Update patient_identifier SET voided = 0 WHERE voided = 5") rescue nil

end

def get_art_patients
  art_encounters = ['HIV CLINIC REGISTRATION','HIV RECEPTION','VITALS',
    'HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING']

  encounter_type = EncounterType.find(:all,:conditions =>["name IN(?)",art_encounters]).map(&:id)

  Patient.find(:all,:joins =>"INNER JOIN encounter e 
    ON e.patient_id = patient.patient_id AND e.voided = 0",
    :conditions =>["encounter_type IN(?)",encounter_type],
    :group => "patient.patient_id")
end


load_patients
