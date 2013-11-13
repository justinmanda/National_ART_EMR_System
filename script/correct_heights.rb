
def correct_heights
  concept_id = ConceptName.find_by_name("height (cm)").concept_id
  #Move value_text to value_numeric
  puts "1: Correcting actual heights"
  heights = Observation.find_by_sql("
              SELECT obs_id, person_id, value_text FROM obs WHERE concept_id = #{concept_id}
              AND value_text IS NOT NULL
              AND value_text != ''
              AND value_text != 'unknown'
              AND voided = 0
              ")
            heights.each { |height|
                ActiveRecord::Base.transaction do
                    obs = Observation.find(height.obs_id)
                    obs.value_numeric = height.value_text
                    obs.value_text = nil
                    obs.save
                    puts "patient id #{height.person_id} with height #{height.value_text}"
              end

            }

   #Set empty value_text to nil
   puts "2: Nullifying empty fields"
   heights = Observation.find_by_sql("
              SELECT obs_id, person_id, value_numeric FROM obs WHERE concept_id = #{concept_id}
              AND value_text IS NOT NULL
              AND value_text = ''
              AND voided = 0
              ")
            heights.each { |height|
              ActiveRecord::Base.transaction do
                  obs = Observation.find(height.obs_id)
                  obs.value_text = nil
                  obs.save
                  puts "patient id #{height.person_id} with height #{height.value_numeric}"
              end
            }

end

correct_heights