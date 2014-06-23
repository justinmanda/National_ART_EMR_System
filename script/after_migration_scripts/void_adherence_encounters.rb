=begin

Creator 	:     	Precious Ulemu Bondwe
Date    	:     	2013-08-28 
Purpose 	:     	To void all adherence encounters with their corresponding observations. 
	              	This allows recalculation of adherence in case adherence was not calculated properly. 
pre-requisite	:	MAKE SURE THE location_id IS SET TO THE LOCATION ID OF THE HEALTH CENTER THE MIGRATION IS FOR:
amendments	:	********** INCLUDE AMENDMENTS HERE  ***************
=end

def start

adherence_encounters = Encounter.find(:all, :conditions => ["encounter_type = ? AND voided = 0", 68])
counter = 0
location_id = 10
puts ">>>>>>>Starting<<<<<<<"

	#set Location first
	location = Location.find(location_id)
	Location.current_location = location
	#end of setting location

	adherence_encounters.each do |adh_enc|
		#puts "#{adh_enc.to_yaml}"
		counter = counter + 1

		obs = Observation.find(:all, :conditions => ["encounter_id = ? AND voided = 0", adh_enc.encounter_id])
		obs.each do |aObs|
			if aObs.voided != true
				aObs.void
			end
		end

     ActiveRecord::Base.connection.execute <<EOF
UPDATE encounter
SET voided = 1
WHERE encounter_id = #{adh_enc.encounter_id}
EOF
		#if adh_enc.voided != true
		#	adh_enc.void
		#end
		#adh_enc.save
		puts ">>>>> #{adherence_encounters.length - counter}....of....#{adherence_encounters.length}.....remaining!"
	end
puts ">>>>>> Finished <<<<<<"
end
start
