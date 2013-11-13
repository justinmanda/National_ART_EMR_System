
$user = User.find_by_username('admin')

def start

  puts "BART patient merge script"
  puts ""

  proceed = true
  primary = nil
  secondary = nil

  while proceed

    until !primary.blank?
      puts ""
      print "Enter patient id of primary patient: "
      primary = gets.to_i rescue nil
    end

    until !secondary.blank?
      puts ""
      print "Enter patient id of patient to be voided: "
      secondary = gets.to_i rescue nil
    end

    merge(primary, secondary)

    puts ""
    print "Do you want to merge other patients (Yes/No)?"
    ans = gets.upcase.squish!

    if ans.eql?("YES")

      proceed = true
    else
      proceed = false
    end

    primary = nil
    secondary = nil

  end


end

def merge(patient_id, secondary_patient_id)
  patient = Patient.find(patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}]) rescue nil
  secondary_patient = Patient.find(secondary_patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}]) rescue nil

  unless (patient.blank? || secondary_patient.blank?)

    ActiveRecord::Base.transaction do
      secondary_patient.patient_identifiers.each {|r|
        if patient.patient_identifiers.map(&:identifier).each{| i | i.upcase }.include?(r.identifier.upcase)
          ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{$user.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier_type = #{r.identifier_type}
          AND identifier = '#{r.identifier}'")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND identifier_type = #{r.identifier_type}
AND identifier = "#{r.identifier}"
EOF
        end
      }

      secondary_patient.person.names.each {|r|
        if patient.person.names.map{|pn| "#{pn.given_name.upcase rescue ''} #{pn.family_name.upcase rescue ''}"}.include?("#{r.given_name.upcase rescue ''} #{r.family_name.upcase rescue ''}")
          ActiveRecord::Base.connection.execute("
        UPDATE person_name SET voided = 1, date_voided=NOW(),voided_by=#{$user.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}
        AND person_name_id = #{r.person_name_id}")
        end
      }

      secondary_patient.person.addresses.each {|r|
        if patient.person.addresses.map{|pa| "#{pa.city_village.upcase rescue ''}"}.include?("#{r.city_village.upcase rescue ''}")
          ActiveRecord::Base.connection.execute("
        UPDATE person_address SET voided = 1, date_voided=NOW(),voided_by=#{$user.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE person_address SET person_id = #{patient_id}
WHERE person_id = #{secondary_patient_id}
AND person_address_id = #{r.person_address_id}
EOF
        end
      }

      secondary_patient.patient_programs.each {|r|
        if patient.patient_programs.map(&:program_id).include?(r.program_id)
          ActiveRecord::Base.connection.execute("
        UPDATE patient_program SET voided = 1, date_voided=NOW(),voided_by=#{$user.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}
        AND patient_program_id = #{r.patient_program_id}")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND patient_program_id = #{r.patient_program_id}
EOF
        end
      }

      ActiveRecord::Base.connection.execute("
        UPDATE patient SET voided = 1, date_voided=NOW(),voided_by=#{$user.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}")

      ActiveRecord::Base.connection.execute("UPDATE person_attribute SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE person_address SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE encounter SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE obs SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE note SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
      #ActiveRecord::Base.connection.execute("UPDATE person SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    end

    puts "Successfully merged patient #{patient_id} and #{secondary_patient_id}"
  else
    puts "Failed to merge patients'"
  end

end


start