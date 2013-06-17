

query = " SELECT * FROM temp_states_list"

outcomes_array = Encounter.find_by_sql(query) 
states = {3 => "PATIENT DIED", 2 => "PATIENT TRANSFERRED OUT", 6 => "TREATMENT STOPPED"}

aUser = User.find_by_username('admin')
user = aUser.user_id
User.current = aUser

puts "Start Time: #{Time.now}\n\n"
puts "looping through #{count = outcomes_array.length} records ....\n"
sleep 5

outcomes_array.each do |aOutcome|

  	location = Location.find(700)
  	Location.current_location = location
    new_encounter = {"encounter_datetime"=> aOutcome.start_date,
      			         "encounter_type_name"=>"EXIT FROM HIV CARE",
      			         "patient_id"=> aOutcome.patient_id,
            				 "location_id" => 700,
            				 "provider_id" => user,
      			         "creator"=> user}

    encounter = Encounter.new(new_encounter)
    #encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
    encounter.save

    reason_obs = {} 
    reason_obs[:concept_name] = 'REASON FOR EXITING CARE'
    reason_obs[:encounter_id] = encounter.id
    reason_obs[:obs_datetime] = encounter.encounter_datetime
    reason_obs[:person_id] ||= encounter.patient_id
    reason_obs[:value_coded_or_text] = states[aOutcome.state.to_i]
    reason_obs[:creator] = user
    Observation.create(reason_obs)

    date_obs = {} 
    date_obs[:concept_name] = 'DATE OF EXITING CARE'
    date_obs[:encounter_id] = encounter.id
    date_obs[:obs_datetime] = encounter.encounter_datetime
    date_obs[:person_id] ||= encounter.patient_id
    date_obs[:value_datetime] = aOutcome.start_date.to_date
    date_obs[:creator] = user
    Observation.create(date_obs)
  
  puts "#{count -= 1} of #{outcomes_array.length} records ....\n"
end

puts "finished creating exit from care encounters .......\n"  

puts "End Time: #{Time.now}\n"
