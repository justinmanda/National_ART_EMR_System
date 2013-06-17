class MysqlConnection < ActiveRecord::Base
  self.establish_connection(:adapter => 'mysql2', :database => 'mpc_tb_data', :password => "t1m0", :host => "localhost") 
end


$tb_place = {1 => Location.find_by_name("martin preuss centre").id, 2=> Location.find_by_name("other").id, 9=> Location.find_by_name("unknown").id}

$tb_type = { 1 => Concept.find_by_name("pulmonary tb").id, 2 => Concept.find_by_name("eptb").id, 9 => Concept.find_by_name("unknown").id}

$pat_cat = { 1 => Concept.find_by_name("NEW PATIENT").id, 2 => Concept.find_by_name("Relapse").id, 3 => Concept.find_by_name("Retreatment after default TB case").id, 4 => Concept.find_by_name("TB retreatment after failure case").id, 5 => Concept.find_by_name("Other").id , 9 => Concept.find_by_name("unknown").id}

$tb_txreg ={1 => Concept.find_by_name("RHZE").id, 2 => Concept.find_by_name("Isoniazid").id, 3 => Concept.find_by_name("Pyrazinamide").id, 4 => Concept.find_by_name("Ethambutol").id , 5 => Concept.find_by_name("Streptomycin").id , 6 => Concept.find_by_name("Other").id,7 =>Concept.find_by_name("RHZ").id , 8 => Concept.find_by_name("RH+Z+S").id, 9 => Concept.find_by_name("unknown").id, 10 => Concept.find_by_name("RHZE+S").id , 11 => Concept.find_by_name("RH+Z+S").id} 

$smear_initial = {1 => Concept.find_by_name("moderately positive").id, 2 => Concept.find_by_name("negative").id, 3 => Concept.find_by_name("unknown").id }

$tb_outc = { 1 => Concept.find_by_name("currently in treatment").fullname, 2 => Concept.find_by_name("patient cured").fullname, 3 => Concept.find_by_name("treatment complete").fullname, 4 => Concept.find_by_name("patient died").fullname, 5 => Concept.find_by_name("Defaulted").fullname, 6 => Concept.find_by_name("patient transferred out").fullname, 7 =>  Concept.find_by_name("regimen failure").fullname, 9 => Concept.find_by_name("unknown").fullname }

$hiv_status = { 1 => Concept.find_by_name("positive").id, 0 => Concept.find_by_name("negative").id, 2 => Concept.find_by_name("unknown").id, 9 => Concept.find_by_name("unknown").id }


$arv_status = {1 => Concept.find_by_name("Yes").id, 2 => Concept.find_by_name("Yes").id, 3 => Concept.find_by_name("No").id, 9 => Concept.find_by_name("Unknown").id}

$creator = User.find_by_username("migrator").id 
$provider = User.find_by_username("mikkal").person_id 


def import

	mpc_records = MysqlConnection.connection.select_all("SELECT * FROM CSVImport limit 3")
	encounter_types = [EncounterType.find_by_name("TB_initial").id,EncounterType.find_by_name("TB registration").id,EncounterType.find_by_name("TB visit").id,EncounterType.find_by_name("treatment").id,EncounterType.find_by_name("Dispensing").id, EncounterType.find_by_name("update hiv status").id,EncounterType.find_by_name("lab results").id, EncounterType.find_by_name("tb clinic visit").id, EncounterType.find_by_name("give lab results").id]	
	
	count = mpc_records.length
	puts "Patients to be migrated #{count}"
	mpc_records.each do |record|

		puts "#{count} patients to go. Current Patient: #{record['patientID']}, Record ID: #{record['RecID']} "

		$entry = record
		if (!Patient.find(record['patientID']).nil? rescue false)
				#initialise a global user for all records of the patient
			
			
				#creating encounters
				initial_enc(create_encounter(encounter_types[0],record), record["patientID"],record["smear_initial"].to_i,record["tb_regdate"], 1) 	
		
				if !$smear_initial[record["smear_initial"].to_i].nil?

					accession1 = rand(999999)
					accession2 = rand(999999)
					lab_orders(create_encounter(EncounterType.find_by_name("Lab Orders").id, record), accession1, accession2)
					sputum_submission_orders(create_encounter(EncounterType.find_by_name("sputum submission").id, record), accession1, accession2)
					lab_results_enc(create_encounter(encounter_types[6],record), record["patientID"],record["smear_initial"].to_i,record["tb_regdate"], 1, accession1, accession2) 
					give_lab_results_enc(create_encounter(encounter_types[8],record))

				end

				registration_enc(create_encounter(encounter_types[1],record), record["patientID"],record["pat_cat"],record["tb_type"], record["tb_ID"] ,record["tb_regdate"], 1, record["tb_outc"], record["tb_outcdate"])
	

				visit_enc(create_encounter(encounter_types[2],record), record)
		
					tb_clinic_visit_enc(create_encounter(encounter_types[7],record), record["patientID"],record["tb_regdate"],1, record["arv_status"]) unless $arv_status[record["arv_status"].to_i].nil?
			

				if !record["tb_txreg"].nil? || !record["tb_txreg"] == " "
					treatment_enc(create_encounter(encounter_types[3],record), record)
					treatment_encounter = current_treatment_encounter(Patient.find(record["patientID"]),record["tb_regdate"], $creator)
					unless treatment_encounter.blank?
						dispensation_enc(create_encounter(encounter_types[4],record), record, treatment_encounter)
					end
				end

				if !record["hiv_status"].nil?
					update_hiv_status_enc(create_encounter(encounter_types[5],record), record)
				end		
		end
		count -=1

	end
	
end

def create_encounter(enc_type, record)

		enc = Encounter.new()
		enc.encounter_type = enc_type 
		enc.location_id = $tb_place[1]			
		enc.patient_id = record["patientID"]
		enc.creator = $creator
		enc.provider_id = $provider
		enc.encounter_datetime = record["tb_regdate"]
		enc.save!
		create_obs(record["patientID"], enc.id, Concept.find_by_name("data migration notes").id,Concept.find_by_name("yes").id ,record["tb_regdate"], $tb_place[1] )
		return enc.id

end

def treatment_enc(id, details)

	if !$tb_txreg[details["tb_txreg"].to_i].nil?
		create_obs(details["patientID"], id, Concept.find_by_name("tb regimen type").id,$tb_txreg[details["tb_txreg"].to_i] ,details["tb_regdate"], $tb_place[1] )
	
		create_drug_order(Patient.find(details["patientID"]),details["tb_regdate"],$tb_txreg[details["tb_txreg"].to_i])
	end
	
end

def give_lab_results_enc(enc_id)

	create_obs($entry["patientID"], enc_id, Concept.find_by_name("laboratory results given to patient").id,Concept.find_by_name("yes").id ,$entry["tb_regdate"], $tb_place[1] )
	
end

def create_drug_order(patient,date, regimen)

		user_id = $creator
		encounter = current_treatment_encounter(patient, date, user_id)
		start_date = date.to_time || Time.now
		auto_tb_expire_date = date + 28.days rescue Time.now + 28.days
		auto_tb_continuation_expire_date = date + 28.days rescue Time.now + 28.days
		
		regimens = Regimen.find(:all, :conditions => ["concept_id =?",regimen]).collect{|x|x.regimen_id}
		orders = RegimenDrugOrder.all(:conditions => ["regimen_id in (?)",regimens.join(",")])	
		ActiveRecord::Base.transaction do
			# Need to write an obs for the regimen they are on, note that this is ARV
			# Specific at the moment and will likely need to have some kind of lookup
			# or be made generic
			obs = Observation.create(
				:concept_name => "WHAT TYPE OF TUBERCULOSIS REGIMEN",
				:person_id => patient.id,
				:encounter_id => encounter.encounter_id,
				:value_coded => regimen,
				:obs_datetime => start_date) 
			orders.each do |order|
				drug = Drug.find(order.drug_inventory_id)
				regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept.name).name
				DrugOrder.write_order(
					encounter, 
					patient, 
					obs, 
					drug, 
					start_date, 
					auto_tb_expire_date, 
					order.dose, 
					order.frequency, 
					order.prn,
  				"#{drug.name}: #{order.instructions} (#{regimen_name})",
					order.equivalent_daily_dose)  
			end 
		end

end


def dispensation_enc(encounter_id, details, treatment_encounter)
	treatment_encounter.orders.each do |order|
		obs = Observation.new()
		obs.person_id = details["patientID"]
		obs.creator = $creator
		obs.location_id = $tb_place[1]
		obs.value_numeric = 60.0
		obs.value_drug = order.drug_order.drug_inventory_id
		obs.concept_id = Concept.find_by_name("Amount dispensed").id
		obs.encounter_id = encounter_id
		obs.obs_datetime = details["tb_regdate"]
		obs.order_id = order.id
		obs.save!
		
		drug_order = order.drug_order
		drug_order.quantity = 60.0
		drug_order.save!
	end
end

def initial_enc(enc_id, pat_id, smear_result, reg_date, location)

	if $entry["pat_cat"] == " " || $entry["pat_cat"] == nil
		ans = Concept.find_by_name("unknown").id
	
	elsif $entry["pat_cat"] == "1"
		ans = Concept.find_by_name("yes").id
	else
		ans = Concept.find_by_name("no").id
	end

	create_obs(pat_id, enc_id,Concept.find_by_name("ever received tb treatment").id,ans, reg_date,$tb_place[location])

end

def lab_orders(enc_id, accession1, accession2) 

	create_lab_results($entry["patientID"], enc_id, Concept.find_by_name("tests ordered").id, Concept.find_by_name("AAFB(1st)").id, $entry["tb_regdate"],$tb_place[1], accession1)

	create_lab_results($entry["patientID"], enc_id, Concept.find_by_name("tests ordered").id ,Concept.find_by_name("AAFB(2nd)").id, $entry["tb_regdate"],$tb_place[1], accession2)

end

def	sputum_submission_orders(enc_id, accession1, accession2) 

	create_lab_results($entry["patientID"], enc_id, Concept.find_by_name("sputum submission").id, Concept.find_by_name("AAFB(1st)").id, $entry["tb_regdate"],$tb_place[1], accession1)

	create_lab_results($entry["patientID"], enc_id, Concept.find_by_name("sputum submission").id ,Concept.find_by_name("AAFB(2nd)").id, $entry["tb_regdate"],$tb_place[1], accession2)


end

def lab_results_enc(enc_id, pat_id,smear_result,reg_date, location, accession1, accession2) 

	create_lab_results(pat_id, enc_id, Concept.find_by_name("AAFB(1st) results").id,$smear_initial[smear_result], reg_date,$tb_place[location], accession1)
	create_lab_results(pat_id, enc_id, Concept.find_by_name("AAFB(2nd) results").id,$smear_initial[smear_result], reg_date,$tb_place[location],accession2)
	
	if $smear_initial[smear_result] == 1
		ans = Concept.find_by_name("confirmed tb not on treatment").id
	elsif $smear_initial[smear_result] == 2
		ans = Concept.find_by_name("tb not suspected").id
	else
		ans = Concept.find_by_name("unknown").id
	end
	
	create_obs(pat_id, enc_id,Concept.find_by_name("tb status").id,ans, reg_date,$tb_place[1])

end

def registration_enc(id, pat_id, pat_cat, tb_type, tb_ID, regdate, tb_place, outcome, outcome_date)

	create_obs(pat_id, id, Concept.find_by_name("tb classification").id, $tb_type[tb_type.to_i], regdate, $tb_place[tb_place.to_i]) unless $tb_type[tb_type.to_i].nil?
	create_obs(pat_id, id, Concept.find_by_name("tb patient category").id, $pat_cat[pat_cat.to_i], regdate, $tb_place[tb_place.to_i]) unless $pat_cat[pat_cat.to_i].nil?
	create_obs(pat_id, id, Concept.find_by_name("tb susceptibility").id, Concept.find_by_name("susceptible").id, regdate, $tb_place[1])
	
	if pat_cat.to_i == 1
		create_obs(pat_id, id, Concept.find_by_name("Directly observed treatment option").id, Concept.find_by_name("guardian").id, regdate, $tb_place[1])
	else
		create_obs(pat_id, id, Concept.find_by_name("Directly observed treatment option").id, Concept.find_by_name("hospital").id, regdate, $tb_place[1])
	end
	
	tb_number = PatientIdentifier.new()
	tb_number.patient_id =  pat_id
	tb_number.identifier_type = PatientIdentifierType.find_by_name("district tb number").id
	tb_number.identifier = "MPC-TB " + regdate.to_date.year.to_s+" "+ tb_ID
	tb_number.location_id = $tb_place[tb_place]
	tb_number.creator = $creator
	tb_number.date_created = regdate
	tb_number.save()

	create_patient_program_and_state(pat_id, regdate, outcome, outcome_date)

end


def visit_enc(id, details)

	if details["tb_place"] = "1"
		ans = Concept.find_by_name("yes").id
	else
		ans = Concept.find_by_name("no").id
	end
	
	create_obs(details["patientID"], id,  Concept.find_by_name("continue treatment at this site").id,ans,details["tb_regdate"], $tb_place[1] )

	if (!details["tb_txreg"].nil?)
		create_obs(details["patientID"], id, Concept.find_by_name("prescribe drugs").id,Concept.find_by_name("yes").id,details["tb_regdate"], $tb_place[1] )
		
	end

end


def tb_clinic_visit_enc(enc_id, pat_id,reg_date, tb_place, status)

	if !$entry["arv_status"].nil?
		create_obs(pat_id, enc_id,Concept.find_by_name("on art").id,$arv_status[status.to_i], reg_date,$tb_place[tb_place])

	end

end


def update_hiv_status_enc(enc_id, details)


	create_obs(details["patientID"], enc_id, Concept.find_by_name("hiv status").id,$hiv_status[details["hiv_status"].to_i] ,details["tb_regdate"], $tb_place[1] )

end

def create_obs(pat_id, enc_id, concept, value, date,location )

		obs = Observation.new()
		obs.person_id = pat_id
		obs.creator = $creator
		obs.location_id = location
		obs.value_coded = value
		obs.concept_id = concept
		obs.encounter_id = enc_id
		obs.obs_datetime = date
		obs.save!

end

def create_lab_results(pat_id, enc_id, concept, value, date,location, acc_num )

		obs = Observation.new()
		obs.person_id = pat_id
		obs.creator = $creator
		obs.location_id = location
		obs.value_coded = value
		obs.concept_id = concept
		obs.encounter_id = enc_id
		obs.obs_datetime = date
		obs.accession_number = acc_num
		obs.save!

end

def	create_patient_program_and_state(pat_id, regdate, outcome, outcome_date)

	program = PatientProgram.new()
	program.patient_id = pat_id
	program.program_id = Program.find_by_name("tb program").id
	program.date_enrolled = regdate
	program.creator = $creator
	program.save!
	
	User.current = User.find($creator) 
	patient = Patient.find(pat_id)
#	patient.patient_programs.find_last_by_program_id(Program.find_by_name("TB PROGRAM")).transition(:state => Concept.find_by_name("currently in treatment").id,:start_date => regdate)                
	patient.patient_programs.find_last_by_program_id(Program.find_by_name("TB PROGRAM")).transition(:state => $tb_outc[outcome.to_i],:start_date => outcome_date)                

=begin

	  if found_person.patient.patient_programs.find_last_by_program_id(Program.find_by_name("TB PROGRAM")).blank?
          found_person.patient.patient_programs.create(:program_id => Program.find_by_name("TB PROGRAM").id,
            :date_enrolled => Time.now())                                       
                                                                                
          found_person.patient.patient_programs.find_last_by_program_id(Program.find_by_name("TB PROGRAM")).transition(
             :state => "Active phase",:start_date => Time.now())                
    end          
=end
end

  def current_treatment_encounter(patient, date = Time.now(), provider = user_person_id)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = patient.encounters.find(:first,:conditions =>["encounter_datetime BETWEEN ? AND ? AND encounter_type = ?",
    									date.to_date.strftime('%Y-%m-%d 00:00:00'),
    									date.to_date.strftime('%Y-%m-%d 23:59:59'),
    									type.id])
    encounter ||= patient.encounters.create(:encounter_type => type.id,:encounter_datetime => date, :provider_id => provider)
  end

import
