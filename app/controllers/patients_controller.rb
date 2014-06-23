class PatientsController < GenericPatientsController
  
  def exitcare_dashboard
    @patient = Patient.find(params[:id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
    @exit_states = concept_set("EXIT FROM CARE").flatten.uniq!
    @exit_states.delete("Treatment never started") if CoreService.get_global_property_value('mpc.lighthouse.states') == false
    render :template => 'dashboards/exitcare_dashboard.rhtml', :layout => false
  end

  def exitcare
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    render :template => 'dashboards/exitcare_tab', :layout => false
  end
  def exitcare_history
    @patient = Patient.find(params[:patient_id])
    encounter_type = EncounterType.find_by_name("EXIT FROM HIV CARE").id

    @encounters = Encounter.find(:all,  
      :conditions => [" patient_id = ? AND encounter_type = ?",
        @patient.id, encounter_type])
    @creator_name = {}
    @encounters.each do |encounter|
      id = encounter.creator
      user_name = User.find(id).person.names.first
      @creator_name[id] = '(' + user_name.given_name.first + '. ' + user_name.family_name + ')'
    end
  
    render :template => 'dashboards/exitcare_tab', :layout => false
  end

  def edit_tb_number
    if request.post?
      @number = params[:current]
      @patient_id = params[:id]
      numbers_array = params[:tb_number].chars.each_slice(4).map(&:join)
      x = numbers_array.length - 1
      year = numbers_array[0].to_i
      surfix = ""
      (1..x).each { |i| surfix = "#{surfix}#{numbers_array[i].squish}" }
      if year > Date.today.year || surfix.to_i < 1
        #flash[:notice] = "Date can not be greater than current year Or number can not be 0"
        render :template => "people/find_by_tb_number" and return
      end
      if PatientIdentifier.site_prefix == "MPC"
        prefix = "LL"
      else
        prefix = PatientIdentifier.site_prefix
      end
      tb_number = "#{prefix}-TB #{year} #{surfix.to_i}"
      people = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
                WHERE REPLACE(identifier, ' ', '') = REPLACE('#{tb_number}', ' ', '') AND voided = 0 ")
      if people.length > 0
        flash[:notice] = "Patient found with number #{tb_number}" 
        render :template => "people/find_by_tb_number" and return
      else
        people = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
                WHERE REPLACE(identifier, ' ', '') = REPLACE('#{@number}', ' ', '')
                AND voided = 0 AND identifier_type = 7 AND patient_id = #{@patient_id}").first
        people.identifier = tb_number
        people.save!
        redirect_to "/patients/tb_treatment_card?patient_id=#{@patient_id}" and return
      end
    else
      @number = params[:number]
      @patient_id = params[:id]
      render :template => "people/find_by_tb_number"
    end
  end

  def patient_transfer_out_label(patient_id)
    date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(patient_id)
    demographics = mastercard_demographics(patient)
   
    who_stage = demographics.reason_for_art_eligibility 
    initial_staging_conditions = demographics.who_clinical_conditions.split(';')
    destination = demographics.transferred_out_to
   
    label = ZebraPrinter::Label.new(776, 329, 'T')
    label.line_spacing = 0
    label.top_margin = 30
    label.bottom_margin = 30
    label.left_margin = 25
    label.x = 25
    label.y = 30
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
   
    # 25, 30
    # Patient personanl data 
    label.draw_multi_text("#{Location.current_health_center.name} transfer out label", {:font_reverse => true})
    label.draw_multi_text("To #{destination}", {:font_reverse => false}) unless destination.blank?
    label.draw_multi_text("ARV number: #{demographics.arv_number}", {:font_reverse => true})
    label.draw_multi_text("Name: #{demographics.name} (#{demographics.sex.first})\nAge: #{demographics.age}", {:font_reverse => false})

    # Print information on Diagnosis!
    art_start_date = PatientService.date_antiretrovirals_started(patient).strftime("%d-%b-%Y") rescue nil
    label.draw_multi_text("Stage defining conditions:", {:font_reverse => true})
    label.draw_multi_text("Reason for starting: #{who_stage}", {:font_reverse => false})
    label.draw_multi_text("ART start date: #{art_start_date}",{:font_reverse => false})
    label.draw_multi_text("Other diagnosis:", {:font_reverse => true})
    # !!!! TODO
    staging_conditions = ""
    count = 1
    initial_staging_conditions.each{|condition|
      if staging_conditions.blank?
        staging_conditions = "(#{count}) #{condition}" unless condition.blank?
      else
        staging_conditions+= " (#{count+=1}) #{condition}" unless condition.blank?
      end
    }
    label.draw_multi_text("#{staging_conditions}", {:font_reverse => false})

    # Print information on current status of the patient transfering out!
    init_ht = "Init HT: #{demographics.init_ht}"                    
    init_wt = "Init WT: #{demographics.init_wt}"

    first_cd4_count = "CD count " + demographics.cd4_count if demographics.cd4_count
    unless demographics.cd4_count_date.blank?
      first_cd4_count_date = "CD count date #{demographics.cd4_count_date.strftime('%d-%b-%Y')}"
    end
    # renamed current status to Initial height/weight as per minimum requirements
    label.draw_multi_text("Initial Height/Weight", {:font_reverse => true})
    label.draw_multi_text("#{init_ht} #{init_wt}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count_date}", {:font_reverse => false})
 
    # Print information on current treatment of the patient transfering out!

    demographics.reg = []

    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
    previous_orders = Order.find(:all, :select => "obs.obs_datetime, drug_order.drug_inventory_id", :joins =>"INNER JOIN obs ON obs.order_id = orders.order_id LEFT JOIN drug_order ON orders.order_id = drug_order.order_id",
      :conditions =>["obs.person_id = ? AND obs.concept_id = ?
        	AND obs_datetime <=?",
        patient.id, concept_id, date.strftime('%Y-%m-%d 23:59:59')],
      :order => "obs_datetime DESC")

    previous_date = nil
    drugs = []

    finished = false

    previous_orders.each do |order|
      drug = Drug.find(order.drug_inventory_id)
      next unless MedicationService.arv(drug)
      next if finished

      if previous_date.blank?
        previous_date = order.obs_datetime.to_date
      end
      if previous_date == order.obs_datetime.to_date
        demographics.reg << (drug.concept.shortname || drug.concept.fullname)
        previous_date = order.obs_datetime.to_date
      else
        if !drugs.blank?
          finished = true
        end
      end
    end

    demographics.reg = demographics.reg.uniq.join(" + ")

    label.draw_multi_text("Current ART drugs", {:font_reverse => true})
    label.draw_multi_text("#{demographics.reg}", {:font_reverse => false})
    label.draw_multi_text("Transfer out date:", {:font_reverse => true})
    label.draw_multi_text("#{date.strftime("%d-%b-%Y")}", {:font_reverse => false})

    label.print(1)
  end

  def patient_visit_label(patient, date = Date.today)
    result = Location.find(session[:location_id]).name.match(/outpatient/i)

    unless result
      return mastercard_visit_label(patient,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      encs = patient.encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)
      encs.each {|encounter|
        next if encounter.name.upcase == "REGISTRATION"
        next if encounter.name.upcase == "HIV REGISTRATION"
        next if encounter.name.upcase == "HIV STAGING"
        next if encounter.name.upcase == "HIV CLINIC CONSULTATION"
        next if encounter.name.upcase == "VITALS"
        next if encounter.name.upcase == "ART ADHERENCE"
        encounter.to_s.split("<b>").each do |string|
          concept_name = string.split("</b>:")[0].strip rescue nil
          obs_value = string.split("</b>:")[1].strip rescue nil
          next if string.match(/Workstation location/i)
          next if obs_value.blank?
          label.draw_multi_text("#{encounter.name.humanize} - #{concept_name}: #{obs_value}", :font_reverse => false)
        end
      }
      label.print(1)
    end
  end

  def mastercard_visit_label(patient, date = Date.today)
  	patient_bean = PatientService.get_patient(patient.person)
    visit = visits(patient, date)[date] rescue {}

		owner = " :Patient visit"

		if PatientService.patient_present?(patient.id) == false and PatientService.guardian_present?(patient.id) == true
			owner = " :Guardian Visit"
		end

    return if visit.blank? 
    visit_data = mastercard_visit_data(visit)
    arv_number = patient_bean.arv_number || patient_bean.national_id
    pill_count = visit.pills.collect{|c|c.join(",")}.join(' ') rescue nil

    label = ZebraPrinter::StandardLabel.new
    #label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient_bean.name}(#{patient_bean.sex}) #{owner}",25,60,0,3,1,1,false)
    label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}",25,95,0,2,1,1,false)
    label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    label.draw_text("#{adherence_to_show(visit.adherence).gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    label.draw_text("#{visit_data['next_appointment']}",577,190,0,2,1,1,false) if visit_data['next_appointment']
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      #bold = true if key.include?("side_eff") and data !="None"
      #bold = true if key.include?("arv_given") 
      starting_index = values.first.to_i
      starting_line = start_line 
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    } rescue []
    label.print(2)
  end
  
  def baby_chart

    @patient = Patient.find(params[:patient_id])
    @baby = @patient

    if (@baby.person.gender.downcase.match(/f/i))
      file =  File.open(RAILS_ROOT + "/public/data/weight_for_age_girls.txt", "r")
    else
      file =  File.open(RAILS_ROOT + "/public/data/weight_for_age_boys.txt", "r")
    end
    @file = []

    file.each{ |parameters|

      line = parameters
      line = line.split(" ").join(",")
      @file << line

    }

    #get available weights

    @weights = []
    birthdate_sec = @patient.person.birthdate

    ids = ConceptName.find(:all, :conditions => ["name IN (?)", ["WEIGHT", "BIRTH WEIGHT", "BIRTH WEIGHT AT ADMISSION", "WEIGHT (KG)"]]).collect{|concept|
      concept.concept_id}

    Observation.find(:all, :conditions => ["person_id = ? AND concept_id IN (?)",
        @patient.id, ids]).each do |ob|
      age = ((((ob.value_datetime.to_date rescue ob.obs_datetime.to_date) rescue ob.date_created.to_date) - birthdate_sec).days.to_i/(60*60*24)).to_s rescue nil
      weight = ob.answer_string.to_i rescue nil
      next if age.blank? || weight.blank?
      weight = (weight > 100) ? weight/1000.0 : weight # quick check of weight in grams and that in KG's
      @weights << age + "," + weight.to_s if !age.blank? && !weight.blank?

    end

    if !params[:cur_weight].blank?
      wt = params[:cur_weight].to_f
      weight = (wt > 100) ? wt/1000.0 : wt
      age = (((session[:datetime].to_date rescue Date.today) - birthdate_sec).days.to_i/(60*60*24)).to_s rescue nil
      @weights << age + "," + weight.to_s if !age.blank? && !weight.blank?
    end
    
    if params[:tab]
      render :template => "/patients/tab_baby_chart", :layout => false
    else
      render :template => "/patients/baby_chart", :layout => false
    end
  end

  def set_allow_hiv_staging_sessions
    current_date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(params[:patient_id])
    session["#{patient.id}"] = {} if session["#{patient.id}"].blank?
    session["#{patient.id}"]["#{current_date}"] = {} if session["#{patient.id}"]["#{current_date}"].blank?
    session["#{patient.id}"]["#{current_date}"][:stage_patient] = nil
    render :text => "true" and return
  end

  def set_deny_hiv_staging_sessions
    current_date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(params[:patient_id])
    session["#{patient.id}"] = {} if session["#{patient.id}"].blank?
    session["#{patient.id}"]["#{current_date}"] = {} if session["#{patient.id}"]["#{current_date}"].blank?
    session["#{patient.id}"]["#{current_date}"][:stage_patient] = "No"
    next_url = (next_task(patient))
    render :text => next_url and return
  end
end
