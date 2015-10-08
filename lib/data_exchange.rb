class DataExchange
   #the rest client gem for Restful methods of GET,PUT etc
   require 'rest-client'

  def export_patient_data(patient_obj)
    #get person data
    fields = ["location","person_address_id", "person_name_id","person_name_code_id"]

    person = JSON.parse(Person.find(patient_obj.id).to_json)#.reject!{|key,value| fields.include?(key)}
    person_name = JSON.parse(PersonName.find(:all,
                                             :conditions=>["person_id = ?",
                                                           patient_obj.id]).first.to_json).reject!{|key,value| fields.include?(key)}
    person_address = JSON.parse(PersonAddress.find(:all,
                                                   :conditions=>["person_id = ?",
                                                                 patient_obj.id]).first.to_json).reject!{|key,value| fields.include?(key)}
    person_attribute = JSON.parse(PersonAttribute.find(:all,
                                          :conditions=>["person_id=?",patient_obj.id]).to_json).each {
                                                        |data| data.reject!{|key,value| fields.include?(key)} }
    person_name_code = JSON.parse(PersonNameCode.find(:all,
                                                      :conditions=>["person_name_id = ?",
                                                                    patient_obj.id]).first.to_json).reject!{|key,value| fields.include?(key)}
    #Patient details
    patient = JSON.parse(patient_obj.to_json) #.reject!{|key,value| fields.include?(key)}
    patient_program = JSON.parse(PatientProgram.find(:all,
                                                      :conditions=>["patient_id=?",patient_obj.id]).to_json).each {
                                                        |data| data.reject!{|key,value| fields.include?(key)} }
    patient_identifier = JSON.parse(PatientIdentifier.find(:all,
                                                     :conditions=>["patient_id=?",patient_obj.id]).to_json).each {
                                                       |data| data.reject!{|key,value| fields.include?(key)} }
    program_ids = PatientProgram.find(:all,
                                      :conditions=>["patient_id=?",patient_obj.id]).map(&:patient_program_id)
    patient_state = JSON.parse(PatientState.find(:all,
                                                     :conditions=>["patient_program_id IN (?)",program_ids]).to_json).each {
                                                |data| data.reject!{|key,value| fields.include?(key)} }
    #encounters not to be exported
    excluded_encounters = [EncounterType.find_by_name("HIV CLINIC REGISTRATION").id,EncounterType.find_by_name('HIV STAGING').id]

    encounter_ids = Encounter.find(:all,
                                   :conditions=>["patient_id=? AND encounter_type NOT IN (?)",patient_obj.id,excluded_encounters]).map(&:encounter_id)
    encounters = JSON.parse(Encounter.find(:all,
                                                :conditions=>["patient_id=?",patient_obj.id]).to_json).each {
                                              |data| data.reject!{|key,value| fields.include?(key)} }

    orders = JSON.parse(Order.find(:all,
                                           :conditions=>["encounter_id IN (?)",encounter_ids]).to_json).each {
                                         |data| data.reject!{|key,value| fields.include?(key)} }

    observation = JSON.parse(Observation.find(:all,
                                       :conditions=>["person_id = ? AND encounter_id IN (?)",patient_obj.id,encounter_ids]).to_json).each {
                                       |data| data.reject!{|key,value| fields.include?(key)} }

=begin
    drug_order = JSON.parse(DrugOrder.find(:all,
                                             :conditions=>["encounter_id IN (?)",encounter_ids]).to_json).each {
                                             |data| data.reject!{|key,value| fields.include?(key)} }
=end
  national_id = PatientService.get_national_id(patient_obj)

  patient_data = { "national_id"=> national_id,
                   "person"=> person,"person_name"=>person_name,
                   "person_address"=>person_address,
                   "person_attribute"=> person_attribute,
                   "person_name_code"=> person_name_code,
                   "patient"=>patient,
                   "patient_identifier"=>patient_identifier,
                   "patient_program"=>patient_program,
                   "patient_state"=>patient_state,
                   "encounters"=>encounters,
                   "orders"=>orders,
                   "observation"=>observation
                 }
    #export the data to couchDB instance
    feedback = RestClient.put("http://localhost:5984/patient_details2/#{national_id}",patient_data.to_json,:content_type=>:json,:accept=>:json)

  end

 def create_openMRS_records(patient_obj)
   #This method gets its data from couchDB and save it in openmrs tables
   patient_data = import_couchDB_data(patient_obj)
   #
   person = create_person(patient_data["person"])
   create_names(person,patient_data["person_name"])
   create_address(person,patient_data["person_address"])
   create_person_name_code(person,patient_data["person_name_code"])
   create_attribute(person, patient_data["person_attribute"])
   create_patent(person,patient_data["patient"])
   create_identifier(person,patient_data["patient_identifier"])
   create_patient_prog(person,patient_data["patient_program"],patient_data["patient_state"])
   create_encounter(person,patient_data["encounters"],patient_data["orders"],patient_data["observation"])
 end

 def create_person(person_data)
   #person high level table will be created here
   person = Person.create({"gender"=>person_data["gender"],"birthdate_estimated"=> person_data["birthdate_estimated"],
                           "birthdate"=> person_data["birthdate"],"dead"=>person_data["dead"],
                           "death_date"=>person_data["death_date"],"creator"=>1})
   return person
 end

 def create_names(person,names)
   PersonName.create({"family_name"=>names['family_name'],"middle_name"=>names['middle_name'],
                     "person_id"=>person.id,"given_name"=>names["given_name"],"creator"=>1})
 end

 def create_address(person,person_addr)
   PersonAddress.create({"country"=>person_addr["country"],"address1"=>person_addr["address1"],
                        "address2"=>person_addr["address2"],"neighborhood_cell"=>person_addr["neighborhood_cell"],
                        "person_id"=>person.id,"county_district"=>person_addr["county_district"],
                         "city_village"=>person_addr["city_village"],"state_province"=>person_addr["state_province"],
                         "creator"=>1})
 end

 def create_person_name_code(person,pnc)
   PersonNameCode.create({"middle_name_code"=>pnc["middle_name_code"],"family_name_code"=>pnc["family_name_code"],
                         "given_name_code"=>pnc["given_name_code"],"person_name_id"=>person.id})
 end

 def create_attribute(person, per_atrr)
   per_atrr.each do |attribute|
   PersonAttribute.create({"person_id"=> person.id,"person_attribute_type_id"=>attribute["person_attribute_type_id"],
                           "value"=> attribute["value"],"creator"=>1})
   end
 end

 def create_patent(person,patient)
    Patient.create({"patient_id"=>person.id,"date_created"=>patient["date_created"],"date_changed"=>patient["date_changed"],
                   "creator"=>1})
 end

 def create_identifier(person,identifiers)
    identifiers.each do |identifier|
         PatientIdentifier.create({"identifier_type"=>identifier["identifier_type"],"patient_id"=>person.id,
                                   "identifier"=>identifier[ "identifier"],"creator"=>1,"date_created"=>identifier["date_created"]})
    end
 end

 def create_patient_prog(person,pat_programs,patient_state)
   old_new_program_map = {}
   pat_programs.each do |program|
     program= PatientProgram.create({"date_created"=>pat_programs["date_created"],"date_changed"=>pat_programs["date_changed"],
                     "creator"=>1,"program_id"=>pat_programs["program_id"],"date_enrolled"=> pat_programs["date_enrolled"],
                      "patient_id"=> person.id})

               old_new_program_map[program["patient_program_id"]]=program.id
   end
  create_patient_state(patient_state,old_new_program_map)
 end

 def create_patient_state(states,ids)
  states.each do |state|
    PatientState.create({"date_created"=>patient["date_created"],"date_changed"=>patient["date_changed"],
                         "creator"=>1,"state"=>state["state"],"start_date"=>state["start_date"],
                        "end_date"=>state["end_date"],"patient_program_id"=>ids[state["patient_program_id"]]})
  end

 end

 def create_encounter(person,encounters,orders,observation)
   old_new_encounter_map = {}
   encounters.each do |encounter|
   created_encounter = Encounter.create({"patient_id"=>person.id,"encounter_type"=>encounter["encounter_type"],
                     "encounter_datetime"=>encounter["encounter_datetime"],
                    "creator"=>1,"date_created"=>encounter["date_created"],"date_changed"=>encounter["date_changed"],
                    })
     old_new_encounter_map[encounter["encounter_id"]]= created_encounter.id
   end
   old_new_order_id_map = create_order(person,orders,old_new_encounter_map)
   create_observation(person,observation,old_new_encounter_map,old_new_order_id_map)
 end

 def create_order(person,orders,encounter_ids)
   old_new_order_id_map = {}
    orders.each do |order|
     created_order= Order.create({"accession_number"=>order["accession_number"],"concept_id"=>order["concept_id"],
                                  "instructions"=>order["instructions"],"creator"=>1,"date_created"=>order["date_created"],
                                  "patient_id"=>person.id,"encounter_id"=>encounter_ids[order["encounter_id"]],
                                  "start_date"=>order["start_date"],"auto_expire_date"=>order["auto_expire_date"]})

       old_new_order_id_map[order["order_id"]]= created_order.id
    end
   return old_new_order_id_map
 end

 def create_observation(person,observations,encounter_ids,order_ids)

   observations.each do |observation|
     Observation.create({"accession_number"=>observation["accession_number"],"person_id"=>person.id,
                        "obs_datetime"=>observation["obs_datetime"],"value_boolean"=>observation["value_boolean"],
                        "value_coded_name_id"=> observation["value_coded_name_id"],"value_text"=>observation["value_text"],
                        "value_drug"=> observation["value_drug"],"value_datetime"=> observation["value_datetime"],
                        "creator"=>1,"concept_id"=>observation["concept_id"],"encounter_id"=>encounter_ids[observation["encounter_id"]],
                        "order_id"=>order_ids[observation["order_id"]],"value_coded"=>observation["value_coded"],
                        "value_numeric"=>observation["value_numeric"],"date_created"=>observation["date_created"]})
   end

 end

 def import_couchDB_data(patient_obj)
     national_id = PatientService.get_national_id(patient_obj)
     patient_data = JSON.parse(RestClient.get("http://localhost:5984/patient_details2/#{national_id}"))
     return patient_data
 end

 def discard_field(data)
    fields = ["location","encounter_id","patient_id","person_id","person_address_id",
              "person_name_id","person_name_code_id"]
        if data.length == 1
           data.reject!{|key,value| fields.include?(key)}
        else
           data.each do |row|
             row.reject!{|key,value| fields.include?(key)}
           end
        end
    return data
 end

  def modify_field
    fields = ["creator","voided_by"]
  end
end