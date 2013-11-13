
def update_locations

  PatientProgram.update_all("location_id = "+ Location.current_health_center.location_id.to_s )
	fix_retired_drug
end


def fix_retired_drug

	retired =  DrugOrder.find(:all, :conditions => ["drug_inventory_id = 614"])
	
	retired.each do |drug_order|
	
		dispense_date = drug_order.order.start_date.to_date.year
		dob = drug_order.order.encounter.patient.person.birthdate.to_date.year rescue nil
	
		unless dob.nil?

			age = dispense_date - dob
			dispense_obs = Observation.find(:all, :conditions => ["order_id = ? and value_drug = 614", drug_order.order_id])
		
			if age < 14
				drug_order.drug_inventory_id = Drug.find_by_name('AZT/3TC/NVP (60/30/50mg tablet)').id
			else
				drug_order.drug_inventory_id = Drug.find_by_name('AZT/3TC/NVP (300/150/200mg tablet)').id		
			end
				
			drug_order.save!
			
			dispense_obs.each do |obs|
			
				if age < 14
					obs.value_drug = Drug.find_by_name('AZT/3TC/NVP (60/30/50mg tablet)').id
				else
					obs.value_drug = Drug.find_by_name('AZT/3TC/NVP (300/150/200mg tablet)').id		
				end

				obs.save!
			
			end
			
		end
	end 

end

update_locations
