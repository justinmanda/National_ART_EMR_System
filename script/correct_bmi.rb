CurrentUser = User.find(1)

def bmi
  puts "1: Correct BMI values"
  weight = ConceptName.find_by_name("weight").concept_id
  height = ConceptName.find_by_name("height (cm)").concept_id
  bmi = ConceptName.find_by_name("BODY MASS INDEX, MEASURED").concept_id
  current_date = Date.today

  vitals = Observation.find_by_sql("
      SELECT * FROM encounter e
      INNER JOIN obs o ON o.encounter_id = e.encounter_id
      WHERE e.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'vitals')
      AND o.voided = 0
      ORDER BY obs_datetime DESC
    ")
 
  vitals.each { |vital|
    i = 1
    ActiveRecord::Base.transaction do
      if vital.concept_id == weight
        current_height = Observation.find(:first,
          :conditions => ["concept_id = #{height} AND person_id = #{vital.person_id}
                                      AND obs_datetime <= '#{vital.obs_datetime}'"],
          :order => "obs_datetime DESC")

        new_bmi = Observation.find(:first,
          :conditions => ["concept_id = #{bmi} AND person_id = #{vital.person_id}
                                      AND encounter_id = #{vital.encounter_id}"])
   
        unless current_height.blank?
          if ! current_height.value_numeric.blank?
            current_height.value_numeric = current_height.value_numeric
            current_weight = vital.to_s.split(':')[1].to_f
            ht = current_height.value_numeric * current_height.value_numeric
            current_bmi = (current_weight / ht)* 10000
            current_bmi = current_bmi.round(1)
              
            new_bmi.encounter_id = vital.encounter_id
            new_bmi.value_numeric = current_bmi
            new_bmi.save
            puts "#{i} Changed to : #{new_bmi}"
            i += 1

          end
        end
      end
    end

  }
end

bmi