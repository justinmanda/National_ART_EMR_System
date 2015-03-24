class ReportController < GenericReportController

	def set_appointments
    @logo = CoreService.get_global_property_value('logo').to_s rescue ''
    @current_location_name = Location.current_health_center.name
    @report_name = 'Appointments Report' #find means of making the report name dynamic
		@select_date = params[:user_selected_date].to_date rescue Date.today
    @formatted_appointment_date = @select_date.strftime('%A, %d - %b - %Y')
		@patients = appointments_for_the_day(@select_date)
		render :layout => 'report'
	end

	def appointments_for_the_day(date = Date.today, identifier_type = 'Filing number')
    	concept_id = ConceptName.find_by_name("Appointment date").concept_id

		records = Observation.find(:all,
			:conditions =>["obs.concept_id = ? AND value_datetime >= ? AND value_datetime <=?",
				concept_id, date.strftime('%Y-%m-%d 00:00:00'), date.strftime('%Y-%m-%d 23:59:59')],
			:order => "obs.obs_datetime DESC")

		demographics = {}
		(records || []).each do |r|
			patient = PatientService.get_patient(Person.find(r.person_id))
			demographics[r.obs_id] = {	:first_name => patient.first_name,
										:last_name => patient.last_name,
										:gender => patient.sex,
										:birthdate => patient.birth_date,
										:visit_date => r.obs_datetime,
										:patient_id => r.person_id,
										:identifier => patient.filing_number || patient.arv_number }
		end
		return demographics
	end

  def get_visits_on(date)
    required_encounters = ["ART ADHERENCE", "ART_FOLLOWUP",   "HIV CLINIC REGISTRATION",
			"HIV CLINIC CONSULTATION",     "HIV RECEPTION",  "HIV STAGING",   "VITALS"]

    required_encounters_ids = required_encounters.inject([]) do |encounters_ids, encounter_type|
      encounters_ids << EncounterType.find_by_name(encounter_type).id rescue nil
      encounters_ids
    end
    #raise date.to_yaml

    required_encounters_ids.sort!

    Encounter.find(:all,
      :joins      => ["INNER JOIN obs     ON obs.encounter_id    = encounter.encounter_id",
				"INNER JOIN patient ON patient.patient_id  = encounter.patient_id"],
      :conditions => ["obs.voided = 0 AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",required_encounters_ids,date],
      :group      => "encounter.patient_id,DATE(encounter_datetime)",
      :order      => "encounter.encounter_datetime ASC")
  end

  def drug_menu
    render :layout => "menu"
  end

  def drug_report
    @logo = CoreService.get_global_property_value('logo') rescue nil
    @location_name = Location.current_health_center.name rescue nil
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    start_date = (start_year + '-' + start_month + '-' + start_day).to_date
    @start_date = start_date
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    end_date = (end_year + '-' + end_month + '-' + end_day).to_date
    @end_date = end_date

    @drugs = {}
    
    drug_order_id = OrderType.find_by_name('Drug Order').id
    #orders = Order.find(:all, :conditions => ["DATE(date_created) >= ? and DATE(date_created) <= ?
       #AND order_type_id =?",start_date, end_date, drug_order_id])
    orders = Order.find_by_sql(["SELECT * FROM orders WHERE DATE(date_created) >= ? AND
                                 DATE(date_created) <= ? AND order_type_id =? AND voided = 0",start_date, end_date, drug_order_id])
    orders.each do |order|
      next if order.drug_order.drug.blank?
      @drugs[order.drug_order.drug.name] = {}
      amount_prescribed = []
      drug_id = order.drug_order.drug_inventory_id rescue nil
      drug_orders = DrugOrder.find_by_sql(["SELECT * FROM drug_order INNER JOIN orders ON
      drug_order.order_id = orders.order_id WHERE DATE(orders.date_created) >= ? AND
      DATE(orders.date_created) <= ? AND drug_order.drug_inventory_id =? AND orders.voided = 0", start_date, end_date,drug_id])
      drug_orders.each do |drug_order|
        if (drug_order.order rescue nil) #Avoid a drug_order without an order. Consider data cleaning
          order_date = drug_order.order.date_created.to_date
          if (order_date >= start_date && order_date <= end_date)
            equivalent_daily_dose = drug_order.equivalent_daily_dose
            duration =  (drug_order.order.auto_expire_date.to_date - drug_order.order.start_date.to_date).to_i rescue nil
            amount_prescribed << (equivalent_daily_dose * duration) rescue nil
          end
        end
      end
      amount_prescribed = amount_prescribed.sum{|value|value.to_i}
      if (@drugs[order.drug_order.drug.name][:amount_prescribed].blank?)
      	@drugs[order.drug_order.drug.name][:amount_prescribed] = amount_prescribed
      else
      	@drugs[order.drug_order.drug.name][:amount_prescribed] += amount_prescribed
      end

      #observations = Observation.find(:all,:conditions => ["DATE(date_created) >= ? and DATE(date_created) <= ?
       #and value_drug =?" ,start_date, end_date, order.drug_order.drug_inventory_id] )
      observations = Observation.find_by_sql(["SELECT * FROM obs WHERE DATE(date_created) >= ? AND
 DATE(date_created) <= ? AND value_drug =?  AND voided = 0" ,start_date, end_date, order.drug_order.drug_inventory_id])
      unless (observations == [])
        quantity = observations.map(&:value_numeric)
        quantity = quantity.sum{|value|value.to_i}
        if ( @drugs[order.drug_order.drug.name][:amount_dispensed].blank?)
        	@drugs[order.drug_order.drug.name][:amount_dispensed] = quantity
        else
        	@drugs[order.drug_order.drug.name][:amount_dispensed] += quantity
        end
      else
        @drugs[order.drug_order.drug.name][:amount_dispensed] = 0
      end
    end
	@drugs
  render:layout=>"report"
  end

  def art_register

    @data = []

    program = Program.find_by_name('HIV PROGRAM').id

    patients = PatientProgram.find(:all, :conditions => ["program_id = ? AND date_completed  IS NULL", program])

    patients.each do |patient|

      det_patient = Patient.find(patient.patient_id) rescue nil
      unless det_patient.nil?

        drug = ConceptName.find_by_concept_id(patient.current_regimen).name rescue nil
        state = patient.patient_states.last.name rescue nil
        start_date = patient.patient_states.last.start_date.strftime('%d/%b/%Y') rescue " "

        arv_id= PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id

        arv_number = PatientIdentifier.find(:first,
                                                              :select => "identifier",
                                                              :conditions  =>["patient_id = ? and identifier_type = ?",
                                                                              encounter.patient_id, arv_id],
                                                              :order => "date_created DESC" ).identifier rescue nil

        detail ={
            'arv_number' => PatientService.get_patient_identifier(det_patient.person, 'ARV Number'),
            'name' => det_patient.name,
            'gender' => det_patient.person.gender,
            'age' => PatientService.age(det_patient.person, Date.today),
            'reg_date' => patient.date_enrolled.to_date.strftime('%d/%b/%Y'),
            'start_reason' =>PatientService.reason_for_art_eligibility(det_patient)  ,
            'outcome' => state.nil? ? " ": state,
            'outcome_date' => start_date,
            'occupation' => PatientService.get_attribute(det_patient , 'Occupation'),
            'formulation' => drug.nil? ? " " : drug
            }
        @data << detail
      end
      @data = @data.uniq

    end

  end

  def missed_appointment_duration
    render :layout => "menu"
  end
  def missed_appointment_report

    @data = []
    @report = "Missed appointments"
    @start_date = (params[:start_month].to_s + "/" + params[:start_day].to_s + "/" + params[:start_year].to_s).to_date

    @end_date = (params[:end_month].to_s + "/" + params[:end_day].to_s + "/" + params[:end_year].to_s).to_date


    appoinment = Concept.find_by_name('appointment date').concept_id

    last_appointments = Observation.find_by_sql("SELECT person_id, obs_datetime ,value_datetime FROM obs
                                WHERE concept_id = #{appoinment} AND DATE(value_datetime) BETWEEN DATE('#{@start_date }')
                                AND DATE('#{@end_date}') AND voided = 0")
    
    last_appointments.each do |last_app|

      last_obs = Observation.find_by_sql("SELECT * FROM obs WHERE person_id = #{last_app.person_id}
                                          AND DATE(obs_datetime) = DATE('#{last_app.value_datetime.to_date}')  LIMIT 1")

       first_obs = Observation.find_by_sql("SELECT person_id, obs_datetime FROM obs
                                            WHERE person_id = #{last_app.person_id}
                                            AND voided = 0 order by obs_datetime ASC LIMIT 1").first
      patient = Patient.find(last_app.person_id)

      
      unless last_obs.blank?
        result = adherence(last_app.person_id, last_app.value_datetime)
        next_visit = Observation.find(:first, :conditions =>  ["person_id = ? AND obs_datetime > ?",
                                                               last_app.person_id, last_app.value_datetime])

        next_visit = next_visit.nil? ? "No" : next_visit.obs_datetime.to_date
        details ={
            'patient_id' => last_app.person_id,
            'name' => patient.name,
            'age' => PatientService.cul_age(patient.person.birthdate , patient.person.birthdate_estimated ),
            'dosses_missed' => result['missed_dosses'],
            'exp_tab_remaining' => result['expected_remaining'] ,
            'booked_date' => last_app.obs_datetime.to_date.strftime('%d/%b/%Y') ,
            'phone_number' => get_phone(last_app.person_id),
            'overdue' => (Date.today.to_date - last_app.obs_datetime.to_date).to_i,
            'came_late' => next_visit,
            'date_registered' => first_obs.obs_datetime.to_date,
            'last_visit_date' => last_app.obs_datetime.to_date
        }
        @data << details
      end

    end


  end
  def defaulted_patients_report
    @data = []
    @report = "defaulted"

    @end_date = (params[:end_month].to_s + "/" + params[:end_day].to_s + "/" + params[:end_year].to_s).to_date

    report = CohortTool.defaulted_patients(@end_date)

    report.each do |person_id|
      patient = Patient.find(person_id)
      appoinment = Concept.find_by_name('appointment date').concept_id

      last_appointment = Observation.find_by_sql("SELECT person_id, obs_datetime ,value_datetime FROM obs
                                WHERE person_id = #{person_id}
                                AND concept_id = #{appoinment} AND DATE(value_datetime) <= DATE('#{@end_date}') AND voided = 0
                                ORDER BY obs_datetime LIMIT 1").first

     
       first_obs = Observation.find_by_sql("SELECT person_id, obs_datetime FROM obs
                                            WHERE person_id = #{person_id}
                                            AND voided = 0 order by obs_datetime ASC LIMIT 1").first
       next_visit = Observation.find(:first, :conditions =>  ["person_id = ? AND obs_datetime > ?",
                                                               person_id, last_appointment.value_datetime])

       next_visit = next_visit.nil? ? "No" : next_visit.obs_datetime.to_date
        unless last_appointment.blank?
              result = adherence(last_appointment.person_id, last_appointment.value_datetime) rescue []
        
          details ={
            'patient_id' => person_id,
            'name' => patient.name,
            'age' => PatientService.cul_age(patient.person.birthdate , patient.person.birthdate_estimated ),
            'dosses_missed' => (result['missed_dosses'] rescue []),
            'exp_tab_remaining' => (result['expected_remaining'] || []),
            'booked_date' => last_appointment.obs_datetime.to_date.strftime('%d/%b/%Y') ,
            'phone_number' => get_phone(person_id),
            'overdue' => (@end_date.to_date - last_appointment.value_datetime.to_date).to_i,
            'came_late' => next_visit,
            'date_registered' => first_obs.obs_datetime.to_date,
            'last_visit_date' => last_appointment.obs_datetime.to_date
        }  
        @data << details
        end
    end

    render "missed_appointment_report"
  end
  
  def get_phone(patient_id)

    patient = Patient.find(patient_id)

    phone = PatientService.get_attribute(patient, "Cell phone number")

    if phone.nil?

      phone = PatientService.get_attribute(patient, "Home phone number")

      if phone.nil?
        phone = PatientService.get_attribute(patient, "Office phone number")
      end

    end

    return phone.nil? ? " " : phone

  end

  def adherence(patient_id, appointment_date)
    #this method has great ability to be reused. We need to make use of it if dealing with adherence

    dispense_concept = Concept.find_by_name('AMOUNT DISPENSED').concept_id
    last_dispense_day = Observation.find_by_sql("SELECT MAX(obs_datetime)  obs_datetime, value_numeric, value_drug,order_id FROM
                             obs WHERE person_id = #{patient_id} AND concept_id = #{dispense_concept} ").first

    order = Order.find(last_dispense_day.order_id) rescue nil

    expected_remaining = last_dispense_day.value_numeric - ((appointment_date.to_date - last_dispense_day.obs_datetime.to_date).to_i * order.drug_order.equivalent_daily_dose) rescue ''

    dosses_missed = (((Date.today.to_date - last_dispense_day.obs_datetime.to_date).to_i * order.drug_order.equivalent_daily_dose) - last_dispense_day.value_numeric )  rescue ""

    return results={ 'missed_dosses' => dosses_missed, 'expected_remaining' => expected_remaining }
  end


end
