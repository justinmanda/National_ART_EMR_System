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
  
end
