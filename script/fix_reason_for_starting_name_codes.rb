
def start

  code_map = { 844 => 863, 1067 => 1104, 1755 => 1915, 5632 => 11442, 7047 => 9789,7048 => 9792, 7051 => 9798, 7052 => 9800, 8207 => 11264, 8262 => 11337 }

  obs = Observation.find_by_sql("select * from obs where concept_id = 7563 and value_coded_name_id is null and voided = 0;")

  (obs || []).each do |ob|

    ob.value_coded_name_id = code_map[ob.value_coded]
    ob.save

  end

end

start