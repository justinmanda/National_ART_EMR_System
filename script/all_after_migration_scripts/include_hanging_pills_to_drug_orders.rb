=begin

Creator : Precious Ulemu Bondwe
Date    : 2013-08-28 
Purpose : To add the pills brought back to the clinic to a particular drug order to 
          help with the adherence calculation. This script has been developed for the 
          data migration process. 
Modifications:
  initials - date - description

=end

def start
  dispensation_obs = Patient.find_by_sql("SELECT order_id, value_numeric, value_drug, person_id, obs_datetime 
    FROM obs WHERE concept_id = 2834 AND voided = 0 AND value_drug IS NOT NULL")
  count = 0
  dispensation_obs.each do |dispensation| 
    count = count + 1
    obs_id = Observation.find_by_sql("SELECT MAX(obs_id) AS our_id FROM obs WHERE  
	concept_id = 2540 AND DATE(obs_datetime) = DATE('#{dispensation.obs_datetime}') AND voided = 0 AND value_drug = #{dispensation.value_drug} 
	AND person_id = #{dispensation.person_id}")
  
    if ! obs_id.first.our_id.nil?
			remaining_pills = Observation.find_by_sql("SELECT value_numeric 
			  FROM obs WHERE obs_id = #{obs_id.first.our_id}")

			if ! remaining_pills.empty?
			  total_quantity = dispensation.value_numeric.to_f + remaining_pills.first.value_numeric.to_f

		ActiveRecord::Base.connection.execute <<EOF
		  UPDATE drug_order
			SET quantity = #{total_quantity}
			WHERE order_id = #{dispensation.order_id}
EOF

			puts "Order_id = #{dispensation.order_id}, Total_dispensed = #{dispensation.value_numeric}, Total_hanging = #{remaining_pills.first.value_numeric.to_f}, Total = #{total_quantity}"
    		end
    end
	puts ">>>>>>  #{dispensation_obs.length - count} of #{dispensation_obs.length}  Remaining  <<<<<<<"
  end
  
end

start
