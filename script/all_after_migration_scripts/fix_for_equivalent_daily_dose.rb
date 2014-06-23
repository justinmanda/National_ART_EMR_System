=begin

Creator :     Precious Ulemu Bondwe
Date    :     2013-08-28 
Purpose :     To update all ARV drug_orders whose equivalent_daily_dose is NULL
              the appropriate equivalent_daily_dose. This helps in the calculation of adherence.
=end

def start
time_started = Time.now

puts "Starting the process at : #{time_started}"

order_query =<<EOF
	SELECT do.order_id, do.drug_inventory_id AS drug_id,
		d.concept_id AS drug_concept_id, 
		o.patient_id, o.date_created 
	FROM drug_order do
	INNER JOIN orders o ON do.order_id = o.order_id
	INNER JOIN drug d ON d.drug_id = do.drug_inventory_id
	WHERE (do.equivalent_daily_dose IS NULL OR do.equivalent_daily_dose = 0) 
EOF

orders = DrugOrder.find_by_sql(order_query)

count = 0
total_orders = orders.length

puts "Drug Orders to Update:==> #{orders.length}"

	orders.each do |order|
		count += 1
		#get encounter_id for vitals
		encounter_query =<<EOF
		SELECT max(e.encounter_id) AS encounter_id
		FROM encounter e
			INNER JOIN obs o on o.encounter_id = e.encounter_id
		WHERE e.patient_id = #{order.patient_id}
			AND e.encounter_type = 6
			AND DATE(encounter_datetime) <= '#{order.date_created.to_date}'
			AND o.concept_id = 5089
			AND o.value_numeric IS NOT NULL
EOF

		visit_encounter = Encounter.find_by_sql(encounter_query).first.encounter_id
			#get weight for the particular visit
		if ! visit_encounter.blank?	
			weight_query =<<EOF
			SELECT value_numeric FROM obs WHERE encounter_id = #{visit_encounter} AND concept_id = 5089
EOF
			visit_weight = Encounter.find_by_sql(weight_query)
				#if weight is 0 or null get next
			if ! visit_weight.empty?
				#get regimen id from regimen table 
				regimen_query =<<EOF
				SELECT regimen_id 
				FROM regimen where concept_id = #{order.drug_concept_id} 
					AND min_weight < #{visit_weight.first.value_numeric} 
					AND #{visit_weight.first.value_numeric} < max_weight
EOF

				regimen = Encounter.find_by_sql(regimen_query)
				
				if ! regimen.empty?
					#get equivalent daily dose, and dose (ruby based)

					regimen_drug_query =<<EOF
					SELECT dose, equivalent_daily_dose 
					FROM regimen_drug_order
					WHERE regimen_id = #{regimen.first.regimen_id}
EOF
	
					regimen_drug = Encounter.find_by_sql(regimen_drug_query)

					if ! regimen_drug.empty?
						update_drug_order(regimen_drug.first.dose, regimen_drug.first.equivalent_daily_dose, order.order_id)
					else
						puts "Failed to find EDD for: Order ID: #{order.order_id}"
					end
				else
					#Check dosage using regimen category if it exists
					reg_category_query = <<EOF
						SELECT max(o.obs_id) AS obs_id
						FROM obs o
						WHERE o.person_id = #{order.patient_id}
							AND DATE(o.obs_datetime) <= '#{order.date_created.to_date}'
							AND o.concept_id = 8375
							AND o.value_text IS NOT NULL 
EOF
					reg_category = Encounter.find_by_sql(reg_category_query)
					
					if ! regimen.empty?
						dosages_query = <<EOF
							SELECT  rdo.dose, rdo.equivalent_daily_dose 
							FROM obs o 
								inner join regimen r
									ON o.value_text = r.regimen_index 
										AND min_weight < #{visit_weight.first.value_numeric}
										AND #{visit_weight.first.value_numeric} < max_weight
								inner join regimen_drug_order rdo
									ON r.regimen_id = rdo.regimen_id
										AND rdo.drug_inventory_id = #{order.drug_id}
							WHERE obs_id = #{reg_category.first.obs_id}

EOF
						dosages = Encounter.find_by_sql(dosages_query)

						if ! dosages.empty?
							update_drug_order(dosages.first.dose, dosages.first.equivalent_daily_dose, order.order_id)
						else
							puts "Failed to find regimen for: Order ID: #{order.order_id}"							
						end
					else
						puts "Failed to find regimen for: Order ID: #{order.order_id}"
					end

				
				end
			else
				puts "Failed to find weight for: Order ID: #{order.order_id}"
			end
		else
			puts "Failed to find vitals encounter for: Order ID: #{order.order_id}"
		end
	end

puts "Finished the process at #{Time.now}"

end

def update_drug_order(dose, equivalent_daily_dose, order_id)
	#update the drug orders table
	ActiveRecord::Base.connection.execute <<EOF
	UPDATE drug_order
	  SET dose = #{dose},
		equivalent_daily_dose = #{equivalent_daily_dose}
	  WHERE order_id = #{order_id}
EOF
end
start
