class Patient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include Openmrs

  has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :programs, :through => :patient_programs
  has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :orders, :conditions => {:voided => 0}
  has_many :encounters, :conditions => {:voided => 0} do 

 def find_by_date(encounter_date)
      encounter_date = Date.today unless encounter_date
      find(:all, :conditions => ["encounter_datetime BETWEEN ? AND ?", 
           encounter_date.to_date.strftime('%Y-%m-%d 00:00:00'), 
           encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')
      ]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end
  
def physical_address
    return PersonAddress.find_by_person_id(self.id, :conditions => "voided = 0").city_village rescue nil
end

def name
    "#{self.person.names[0].given_name rescue ''} #{self.person.names[0].family_name rescue ''}"
end

def self.duplicates(attributes)
    search_str = ''
    ( attributes.sort || [] ).each do | attribute |
      search_str+= ":#{attribute}" unless search_str.blank?
      search_str = attribute if search_str.blank?
    end rescue []

    return if search_str.blank?
    duplicates = {}
    patients = Patient.find(:all) # AND DATE(date_created >= ?) AND DATE(date_created <= ?)",
              #'2005-01-01'.to_date,'2010-12-31'.to_date])

    ( patients || [] ).each do | patient |
      if search_str.upcase == "DOB:NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] = [] if duplicates["#{patient.name}:#{patient.person.birthdate}"].blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "DOB:ADDRESS"
        next if patient.physical_address.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] = [] if duplicates["#{patient.name}:#{patient.physical_address}"].blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.birthdate.blank?
        next if patient.person.addresses.last.county_district.blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] = [] if duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"].blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB"
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.birthdate}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS:NAME"
        next if patient.name.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.name}"].blank?
          duplicates["#{patient.physical_address}:#{patient.name}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.person.birthdate.blank?
        if duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"].blank?
          duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] = []
        end
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB:LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS"
        next if patient.physical_address.blank?
        if duplicates[patient.physical_address].blank?
          duplicates[patient.physical_address] = []
        end
        duplicates[patient.physical_address] << patient
      elsif search_str.upcase == "DOB"
        next if patient.person.birthdate.blank?
        if duplicates[patient.person.birthdate].blank?
          duplicates[patient.person.birthdate] = []
        end
        duplicates[patient.person.birthdate] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        if duplicates[patient.person.addresses.last.county_district].blank?
          duplicates[patient.person.addresses.last.county_district] = []
        end
        duplicates[patient.person.addresses.last.county_district] << patient
      elsif search_str.upcase == "NAME"
        next if patient.name.blank?
        if duplicates[patient.name].blank?
          duplicates[patient.name] = []
        end
        duplicates[patient.name] << patient
      end
    end
    hash_to = {}
    duplicates.each do |key,pats |
      next unless pats.length > 1
      hash_to[key] = pats
    end
    hash_to
   end
   
def self.merge(patient_id, secondary_patient_id)
    patient = Patient.find(patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    secondary_patient = Patient.find(secondary_patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    sec_pt_arv_numbers = PatientIdentifier.find(:all, :conditions => ["patient_id =? AND identifier_type =?",
      secondary_patient_id, PatientIdentifierType.find_by_name('ARV NUMBER').id]).map(&:identifier) rescue []

    unless sec_pt_arv_numbers.blank?
      sec_pt_arv_numbers.each do |arv_number|
        ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier = '#{arv_number}'")
      end
    end
    
  ActiveRecord::Base.transaction do
    secondary_patient.patient_identifiers.each {|r|
      if patient.patient_identifiers.map(&:identifier).each{| i | i.upcase }.include?(r.identifier.upcase)
        ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
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
        UPDATE person_name SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}
        AND person_name_id = #{r.person_name_id}")
      end
    }

    secondary_patient.person.addresses.each {|r|
      if patient.person.addresses.map{|pa| "#{pa.city_village.upcase rescue ''}"}.include?("#{r.city_village.upcase rescue ''}")
      ActiveRecord::Base.connection.execute("
        UPDATE person_address SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
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
        UPDATE patient_program SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
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
        UPDATE patient SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}")

    ActiveRecord::Base.connection.execute("UPDATE person_attribute SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE person_address SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE encounter SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE obs SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE note SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    #ActiveRecord::Base.connection.execute("UPDATE person SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
  end
end
end
