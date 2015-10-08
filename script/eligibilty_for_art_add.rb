Source_db= YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['development']["database"]
CONN = ActiveRecord::Base.connection
def initualise
  puts "THIS SCRIPT HELPS TO ADD ART START REASON FOR PATIENTS ON FILE\n\n"
  puts "Enter File Name.........."
  @file =  gets.chomp.to_s
  @root = "/var/www/National_ART_EMR_System/script/"
  puts "Enter Hospital code"
  code = gets.chomp
  @site = "#{code}-ARV-"
  puts "Enter reason for starting\n 1 Patient Pregnant\n 2 BreastFeeding\n 3 Presume condition \n 4 Under 24\n 5 PCR Positive children"
  choice = gets.chomp.to_i
  @reason = get_reason(choice)
  read_file
end

def read_file
  @arv_ids = []
  File.open(@root+@file,"r") do |li|
    li.each_line do |line|
      @arv_ids<<line.chomp
    end
  end
  get_sys_patient_ids(@arv_ids)
end

def get_sys_patient_ids(arv_numbers)
  @sys_patient_id = []
  arv_numbers.each do |arv_number|
    @sys_patient_id << PatientIdentifier.find(:all,:conditions=>["identifier = ?",arv_number]).first.patient_id rescue 0
  end
  add_art_eligibility(@sys_patient_id)
end
#initualise
#puts @sys_patient_id.join(",")
def add_art_eligibility(patient_ids)
  #finding  staging encounter first
  encounter_type = EncounterType.find_by_name("HIV STAGING").id
  
  reason_for_starting_art = @reason
  reason_concept = ConceptName.find_by_sql("SELECT concept_name.concept_id
                                           FROM concept_name concept_name
                                           LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                                           WHERE name = 'Reason for ART eligibility'
                                           AND voided = 0 AND retired = 0 LIMIT 1").first.concept_id

  value_coded = ConceptName.find_by_sql("SELECT concept_name.concept_id
                                                                FROM concept_name concept_name
                                                                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                                                                WHERE name ='#{reason_for_starting_art}'
                                                                AND voided = 0 AND retired = 0 LIMIT 1").first.concept_id


  value_coded_name_id = ConceptName.find_by_sql("SELECT concept_name.concept_name_id
                                                                       FROM concept_name concept_name
                                                                       LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                                                                       WHERE name = '#{reason_for_starting_art}'
                                                                       AND voided = 0 AND retired = 0 LIMIT 1").first.concept_name_id
  patient_ids.each do |patient_id|
    #creating staging encounter first
    staging_encounter = {:patient_id=>patient_id,:creator=>1,:encounter_type=>encounter_type,:date_created=>Time.now,
                         :uuid=>ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid'],
                         :encounter_datetime=>Time.now,:provider_id=>1,:location_id=>500}
    encounter_create = Encounter.create(staging_encounter)
    
    #retrieving encounter_id for the patient
    encounter_id = Encounter.find(:last,:conditions=>["patient_id = ? AND encounter_type = ?",patient_id,encounter_type]).id
    
    #creating the observation for art eligibility
    obs={:person_id=>patient_id,:concept_id => reason_concept,:encounter_id=>encounter_id,:obs_datetime=>Time.now,
        :voided=>0,:value_coded=>value_coded,:value_coded_name_id=>value_coded_name_id,
	      :uuid=>ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid'],:location_id=>500,
	      :creator=>1,:date_created=>Time.now}

    created = Observation.create(obs)
    if created
      puts "Created reason for starting for patient: #{patient_id}"
    end
  end

end
def get_reason(choice)
  case choice
    when 1
      return "Patient pregnant"
    when 2
      return "Breastfeeding"
    when 3
      return "Presumed severe HIV criteria in infants"
    when 4
      return "HIV infected"
    when 5
      return "HIV DNA polymerase chain reaction"
  end
end
initualise