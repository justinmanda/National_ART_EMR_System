require "csv"
HIV_PROGRAM = Program.find_by_name('HIV Program')
UnknownLocation = Location.find_by_name('Unknown')

def start
  User.current = User.find(1)

  arv_numbers = []
  csv_url =  RAILS_ROOT + "/doc/THYOLOTRANSFEREDOUT.csv"
  CSV.foreach("#{csv_url}") do |row|
    arv_number = row[2].to_i rescue 0
    next if arv_number < 1
    arv_numbers << arv_number
  end

  #find a patient using the ARV number and update the outcome
  (arv_numbers || []).each do |arv_number|
    valid_arv_num = "#{PatientIdentifier.site_prefix}-ARV-#{arv_number}"
    patient = PatientIdentifier.find_by_identifier(valid_arv_num).patient rescue nil
    next if patient.blank?
    puts "Patient with arv number #{valid_arv_num} has outcome #{get_outcome(patient)}"
  end
end

def get_outcome(patient)
  patient_program = PatientProgram.find(:first,:conditions =>["patient_id = ? AND
    program_id = ? AND date_completed IS NULL", patient.id, HIV_PROGRAM.id])

  return "None" if patient_program.blank?

  current_active_state = patient_program.patient_states.last rescue []
  "Current state is #{current_active_state.name}" unless current_active_state.blank?
end


start
