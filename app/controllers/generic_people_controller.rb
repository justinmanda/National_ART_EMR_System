class GenericPeopleController < ApplicationController
   
  @@test  = nil
 
	def index
		redirect_to "/clinic"
	end

	def new
		@occupations = occupations
	end

	def identifiers
	end
  
  def create_confirm
    @search_results = {}
    @patients = []
     
    (PatientService.search_demographics_from_remote(params[:user_entered_params]) || []).each do |data|            
      national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil    
      national_id = data["npid"]["value"] if national_id.blank? rescue nil      
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil
                                                                              
      next if national_id.blank?                                                
      results = PersonSearch.new(national_id)                                   
      results.national_id = national_id                                         
      results.current_residence = data["person"]["data"]["addresses"]["city_village"]
      results.person_id = 0                                                     
      results.home_district = data["person"]["data"]["addresses"]["address2"]   
      results.neighborhood_cell = data["person"]["data"]["addresses"]["neighborhood_cell"]   
      results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]                                 
      results.occupation = data["person"]["data"]["occupation"]                 
      results.sex = (gender == 'M' ? 'Male' : 'Female')                         
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date         
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results                            
    end if create_from_dde_server

    (params[:people_ids] || []).each do |person_id|
      patient = PatientService.get_patient(Person.find(person_id))

      results = PersonSearch.new(patient.national_id || patient.patient_id)     
      results.national_id = patient.national_id                                 
      results.birth_date = patient.birth_date                                   
      results.current_residence = patient.current_residence                     
      results.guardian = patient.guardian                                       
      results.person_id = patient.person_id                                     
      results.home_district = patient.home_district                             
      results.neighborhood_cell = patient.home_village                            
      results.current_district = patient.current_district                       
      results.traditional_authority = patient.traditional_authority             
      results.mothers_surname = patient.mothers_surname                         
      results.dead = patient.dead                                               
      results.arv_number = patient.arv_number                                   
      results.eid_number = patient.eid_number                                   
      results.pre_art_number = patient.pre_art_number                           
      results.name = patient.name                                               
      results.sex = patient.sex                                                 
      results.age = patient.age                                                 
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

		(@search_results || {}).each do | npid , data |
			@patients << data
		end

    @parameters = params[:user_entered_params]
    render :layout => 'menu'
  end

	def create_remote
 	  
		if current_user.blank?
		  user = User.authenticate('admin', 'test')
		  sign_in(:user, user) if !user.blank?
      set_current_user	  
		end rescue []

		if Location.current_location.blank?
			Location.current_location = Location.find(CoreService.get_global_property_value('current_health_center_id'))
		end rescue []
    
    
    if create_from_dde_server                                                
       
      passed_params = {"region" => "" ,
				"person"=>{"occupation"=> params["occupation"] ,
					"age_estimate"=> params["patient_age"]["age_estimate"] ,
					"cell_phone_number"=> params["cell_phone"]["identifier"] || nil,
          "home_phone_number"=> params['home_phone']['identifier'] || nil,
          "office_phone_number"=> params['office_phone']['identifier'] || nil,
					"birth_month"=> params["patient_month"],
				 "addresses"=>
            {"state_province"=> params["addresses"]["state_province"],
            "address2"=> params["addresses"]["address2"],
            "address1"=> params["addresses"]["address1"],
            "neighborhood_cell"=> params["addresses"]["neighborhood_cell"],
            "city_village"=> params["addresses"]["city_village"],
            "county_district"=> params["addresses"]["county_district"]},   
					"gender"=>  params["patient"]["gender"],
					"patient"=>"",
					"birth_day"=>  params["patient_day"] ,
					"home_phone_number"=> params["home_phone"]["identifier"] ,
					"names"=>{"family_name"=> params["patient_name"]["family_name"],
						"given_name"=> params["patient_name"]["given_name"],
						"middle_name"=> params["patient_name"]["middle_name"] },
					"birth_year"=> params["patient_year"] },
				"filter_district"=> params["patient"]["birthplace"] ,
				"filter"=>{"region"=> "" ,
					"t_a"=> "",
					"t_a_a"=>""},
				"relation"=>"",
				"p"=>{"'address2_a'"=>"",
					"addresses"=>{"county_district_a"=>"",
						"city_village_a"=>""}},
				"identifier"=>""}
             
      person = PatientService.create_patient_from_dde(passed_params) 
    else
      #raise params["addresses"].to_yaml
      state = params["addresses"]["state_province"] rescue nil
      address2 = params["addresses"]["address2"] rescue nil
      address1 = params["addresses"]["address1"] rescue nil
      address  = params["addresses"]["neighborhood_cell"] rescue nil
      city_village = params["addresses"]["city_village"] rescue nil
      district = params["addresses"]["county_district"] rescue nil
      person_params = {"occupation"=> params[:occupation],
        "age_estimate"=> params['patient_age']['age_estimate'],
        "cell_phone_number"=> params['cell_phone']['identifier'] || nil,
        "home_phone_number"=> params['home_phone']['identifier'] || nil,
        "office_phone_number"=> params['office_phone']['identifier'] || nil,
        "birth_month"=> params[:patient_month],
       "addresses"=>
            {"state_province"=> state,
            "address2"=> address2,
            "address1"=> address1,
            "neighborhood_cell"=> address,
            "city_village"=> city_village,
            "county_district"=> district},   
        "gender" => params['patient']['gender'],
        "birth_day" => params[:patient_day],
        "names"=> {"family_name2"=>"Unknown",
					"family_name"=> params['patient_name']['family_name'],
					"given_name"=> params['patient_name']['given_name'] },
        "birth_year"=> params[:patient_year] }
        
      person = PatientService.create_from_form(person_params)

      if person
        patient = Patient.new()
        patient.patient_id = person.id
        patient.save
        PatientService.patient_national_id_label(patient)
      end
    end

		render :text => PatientService.remote_demographics(person).to_json
	end

	def remote_demographics
		# Search by the demographics that were passed in and then return demographics
		people = PatientService.find_person_by_demographics(params)
		result = people.empty? ? {} : PatientService.demographics(people.first)
		render :text => result.to_json
	end
  
	def art_information
		national_id = params["person"]["patient"]["identifiers"]["National id"] rescue nil
    national_id = params["person"]["value"] if national_id.blank? rescue nil
		art_info = Patient.art_info_for_remote(national_id)
		art_info = art_info_for_remote(national_id)
		render :text => art_info.to_json
	end
 
	def search
    found_person = nil
    if params[:identifier]
      local_results = PatientService.search_by_identifier(params[:identifier])
      
			if local_results.blank? and (params[:identifier].match(/#{Location.current_health_center.neighborhood_cell}-ARV/i) || params[:identifier].match(/-TB/i))
				flash[:notice] = "No matching person found with number #{params[:identifier]}"
				redirect_to :action => 'find_by_tb_number' if params[:identifier].match(/-TB/i)
				redirect_to :action => 'find_by_arv_number' if params[:identifier].match(/#{Location.current_health_center.neighborhood_cell}-ARV/i)
			end

      if local_results.length > 1
        redirect_to :action => 'duplicates' ,:search_params => params
        return
      elsif local_results.length == 1
        if create_from_dde_server
          dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
          dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
          dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
          uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
          uri += "?value=#{params[:identifier].to_s.strip}"
          output = RestClient.get(uri) rescue []
          p = JSON.parse(output) rescue []
          if p.count > 1
            redirect_to :action => 'duplicates' ,:search_params => params
            return
          end
        end
        found_person = local_results.first
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        if create_from_remote
          found_person_data = PatientService.find_remote_person_by_identifier(params[:identifier])
          found_person = PatientService.create_from_form(found_person_data['person']) unless found_person_data.blank?
        end
      end

      if found_person
        if params[:identifier].to_s.strip.length != 6 and create_from_dde_server
          patient = DDEService::Patient.new(found_person.patient)
          national_id_replaced = patient.check_old_national_id(params[:identifier])
          if national_id_replaced.to_s != "true" and national_id_replaced.to_s !="false"
            redirect_to :action => 'remote_duplicates' ,:search_params => params
            return
          end
        end

        if params[:relation]
          redirect_to search_complete_url(found_person.id, params[:relation]) and return
        elsif national_id_replaced.to_s == "true"
          #creating patient's footprint so that we can track them later when they visit other sites
          DDEService.create_footprint(PatientService.get_patient(found_person).national_id, "MOH-ART")
          print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient)) and return
          redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
        else
          #creating patient's footprint so that we can track them later when they visit other sites
          DDEService.create_footprint(PatientService.get_patient(found_person).national_id, "MOH-ART")
          redirect_to :action => 'confirm',:found_person_id => found_person.id, :relation => params[:relation] and return
        end
      end
    end
		
    @relation = params[:relation]
    @people = PatientService.person_search(params)
    @search_results = {}
    @patients = []

    (PatientService.search_from_remote(params) || []).each do |data|
      national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil
      national_id = data["npid"]["value"] if national_id.blank? rescue nil
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil

      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id

      unless data["person"]["data"]["addresses"]["city_village"].match(/hashwithindifferentaccess/i)
        results.current_residence = data["person"]["data"]["addresses"]["city_village"]
      else
        results.current_residence = nil
      end rescue results.current_residence = nil

      unless data["person"]["data"]["addresses"]["address2"].match(/hashwithindifferentaccess/i)
        results.home_district = data["person"]["data"]["addresses"]["address2"]
      else
        results.home_district = nil
      end rescue results.home_district = nil

      unless data["person"]["data"]["addresses"]["county_district"].match(/hashwithindifferentaccess/i)
        results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      else
        results.traditional_authority = nil
      end rescue results.traditional_authority = nil

      results.person_id = 0
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]
      results.occupation = data["person"]["data"]["occupation"]
      results.sex = (gender == 'M' ? 'Male' : 'Female')
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results
    end if create_from_dde_server

    (@people || []).each do | person |
      patient = PatientService.get_patient(person) rescue nil
      next if patient.blank?
      results = PersonSearch.new(patient.national_id || patient.patient_id)
      results.national_id = patient.national_id
      results.birth_date = patient.birth_date
      results.current_residence = patient.current_residence
      results.guardian = patient.guardian
      results.person_id = patient.person_id
      results.home_district = patient.home_district
      results.current_district = patient.current_district
      results.traditional_authority = patient.traditional_authority
      results.mothers_surname = patient.mothers_surname
      results.dead = patient.dead
      results.arv_number = patient.arv_number
      results.eid_number = patient.eid_number
      results.pre_art_number = patient.pre_art_number
      results.name = patient.name
      results.sex = patient.sex
      results.age = patient.age
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

		(@search_results || {}).each do | npid , data |
			@patients << data
		end
	end
  
  def search_from_dde
		found_person = PatientService.person_search_from_dde(params)
    if found_person
      if params[:relation]
        redirect_to search_complete_url(found_person.id, params[:relation]) and return
      else
        redirect_to :action => 'confirm', 
          :found_person_id => found_person.id, 
          :relation => params[:relation] and return
      end
    else
      redirect_to :action => 'search' and return 
    end
  end
   
	def confirm
		session_date = session[:datetime].blank? ? Date.today : session[:datetime].to_date

		if request.post?
			redirect_to search_complete_url(params[:found_person_id], params[:relation]) and return
		end
		@found_person_id = params[:found_person_id] 
		@relation = params[:relation]
		@person = Person.find(@found_person_id) rescue nil
		patient = @person.patient
		#@outcome = patient.patient_programs.last.patient_states.last.program_workflow_state.concept.fullname rescue nil

		@pp = PatientProgram.find(:first, :joins => :location, :conditions => ["program_id = ? AND patient_id = ?", Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id,@person.id]).patient_states.last.program_workflow_state.concept.fullname	rescue ""
		
		@current_hiv_program_state = PatientProgram.find(:first, :joins => :location, :conditions => ["program_id = ? AND patient_id = ? AND location.location_id = ?", Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id,@person.id, Location.current_health_center.location_id]).patient_states.last.program_workflow_state.concept.fullname rescue ''
		@transferred_out = @current_hiv_program_state.upcase == "PATIENT TRANSFERRED OUT"? true : nil
		defaulter = Patient.find_by_sql("SELECT current_defaulter(#{@person.patient.patient_id}, '#{session_date}') 
                                     AS defaulter 
                                     FROM patient_program LIMIT 1")[0].defaulter rescue 0
		@defaulted = "#{defaulter}" == "0" ? nil : true if ! @pp.match(/patient\sdied/i)
		@task = main_next_task(Location.current_location, @person.patient, session_date)		
		@arv_number = PatientService.get_patient_identifier(@person, 'ARV Number')
    @tb_number = PatientService.get_patient_identifier(@person, 'District TB Number') rescue ""
		@patient_bean = PatientService.get_patient(@person)  
		
		
		@art_start_date = PatientService.date_antiretrovirals_started(@person.patient)
    @second_line_treatment_start_date = PatientService.date_started_second_line_regimen(@person.patient) rescue nil
    @duration_in_months = PatientService.period_on_treatment(@art_start_date) rescue nil
		#@duration_in_months = ((Time.now.to_date - @art_start_date.to_date).to_i/28) unless @art_start_date.blank?
   


		@second_line_duration_in_months = PatientService.period_on_treatment(@second_line_treatment_start_date) rescue nil
    @identifier_types = ["Legacy Pediatric id","National id","Legacy National id"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",@identifier_types]
    ).collect{| type |type.id }
                                                                            
		@patient_identifiers = PatientIdentifier.find(:all,                                                
		  :conditions=>["patient_id=? AND identifier_type IN (?)",                  
        patient.id,identifier_types]).collect{| i | i.identifier }
    #if show_lab_results
      @results = Lab.latest_result_by_test_type(@person.patient, 'HIV_viral_load', @patient_identifiers) rescue nil
      @latest_date = @results[0].split('::')[0].to_date rescue nil
      @latest_result = @results[1]["TestValue"] rescue nil
      @modifier = @results[1]["Range"] rescue nil
    #end
    @reason_for_art = PatientService.reason_for_art_eligibility(patient)
    @vl_request = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",
            patient.patient_id, Concept.find_by_name("Viral load").concept_id]
        ).answer_string.squish.upcase rescue nil
    
		render :layout => false
	end

	def tranfer_patient_in
		@data_demo = {}
		if request.post?
			params[:data].split(',').each do | data |
				if data[0..4] == "Name:"
					@data_demo['name'] = data.split(':')[1]
					next
				end
				if data.match(/guardian/i)
					@data_demo['guardian'] = data.split(':')[1]
					next
				end
				if data.match(/sex/i)
					@data_demo['sex'] = data.split(':')[1]
					next
				end
				if data[0..3] == 'DOB:'
					@data_demo['dob'] = data.split(':')[1]
					next
				end
				if data.match(/National ID:/i)
					@data_demo['national_id'] = data.split(':')[1]
					next
				end
				if data[0..3] == "BMI:"
					@data_demo['bmi'] = data.split(':')[1]
					next
				end
				if data.match(/ARV number:/i)
					@data_demo['arv_number'] = data.split(':')[1]
					next
				end
				if data.match(/Address:/i)
					@data_demo['address'] = data.split(':')[1]
					next
				end
				if data.match(/1st pos HIV test site:/i)
					@data_demo['first_positive_hiv_test_site'] = data.split(':')[1]
					next
				end
				if data.match(/1st pos HIV test date:/i)
					@data_demo['first_positive_hiv_test_date'] = data.split(':')[1]
					next
				end
				if data.match(/FU:/i)
					@data_demo['agrees_to_followup'] = data.split(':')[1]
					next
				end
				if data.match(/1st line date:/i)
					@data_demo['date_of_first_line_regimen'] = data.split(':')[1]
					next
				end
				if data.match(/SR:/i)
					@data_demo['reason_for_art_eligibility'] = data.split(':')[1]
					next
				end
			end
		end
		render :layout => "menu"
	end

	# This method is just to allow the select box to submit, we could probably do this better
	def select
    if !params[:person][:patient][:identifiers]['National id'].blank? &&
        !params[:person][:names][:given_name].blank? &&
        !params[:person][:names][:family_name].blank?
      redirect_to :action => :search, :identifier => params[:person][:patient][:identifiers]['National id']
      return
    end rescue nil

    if !params[:identifier].blank? && !params[:given_name].blank? && !params[:family_name].blank?
      redirect_to :action => :search, :identifier => params[:identifier]
    elsif params[:person][:id] != '0' && Person.find(params[:person][:id]).dead == 1
      redirect_to :controller => :patients, :action => :show, :id => params[:person][:id]
    else
			#raise params.to_yaml
      if params[:person][:id] != '0'
        person = Person.find(params[:person][:id])
        patient = DDEService::Patient.new(person.patient)
        patient_id = PatientService.get_patient_identifier(person.patient, "National id")
        if patient_id.length != 6 and create_from_dde_server
          patient.check_old_national_id(patient_id)
					unless params[:patient_guardian].blank?
            print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", "/patients/guardians_dashboard/#{person.id}") and return
					end

          #creating patient's footprint so that we can track them later when they visit other sites
          DDEService.create_footprint(PatientService.get_patient(person).national_id, "MOH-ART")
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient)) and return
        end
        #creating patient's footprint so that we can track them later when they visit other sites
        DDEService.create_footprint(PatientService.get_patient(person).national_id, "BART2 - #{BART_VERSION}")
      end
      redirect_to search_complete_url(params[:person][:id], params[:relation]) and return unless params[:person][:id].blank? || params[:person][:id] == '0'

      redirect_to :action => :new, :gender => params[:gender], 
        :given_name => params[:given_name], :family_name => params[:family_name], 
        :family_name2 => params[:family_name2], :address2 => params[:address2], 
        :identifier => params[:identifier], :relation => params[:relation]
    end
	end

  def create
    if confirm_before_creating and not params[:force_create] == 'true' and params[:relation].blank?
      @parameters = params
      birthday_params = params.reject{|key,value| key.match(/gender/) }
      unless birthday_params.empty?
        if params[:person]['birth_year'] == "Unknown"
          birthdate = Date.new(Date.today.year - params[:person]["age_estimate"].to_i, 7, 1)
        else
          year = params[:person]["birth_year"].to_i
          month = params[:person]["birth_month"]
          day = params[:person]["birth_day"].to_i

          month_i = (month || 0).to_i
          month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
          month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
                                                     
          if month_i == 0 || month == "Unknown"
            birthdate = Date.new(year.to_i,7,1)
          elsif day.blank? || day == "Unknown" || day == 0
            birthdate = Date.new(year.to_i,month_i,15)
          else
            birthdate = Date.new(year.to_i,month_i,day.to_i)
          end
        end
      end
     
      start_birthdate = (birthdate - 5.year)
      end_birthdate   = (birthdate + 5.year)

      given_name_code = @parameters[:person][:names]['given_name'].soundex
      family_name_code = @parameters[:person][:names]['family_name'].soundex
      gender = @parameters[:person]['gender']
      ta = @parameters[:person][:addresses]['county_district']
      home_district = @parameters[:person][:addresses]['address2']
      home_village = @parameters[:person][:addresses]['neighborhood_cell']

      people = Person.find(:all,:joins =>"INNER JOIN person_name pn
       ON person.person_id = pn.person_id
       INNER JOIN person_name_code pnc ON pnc.person_name_id = pn.person_name_id
       INNER JOIN person_address pad ON pad.person_id = person.person_id",
        :conditions =>["(pad.address2 LIKE (?) OR pad.county_district LIKE (?)
       OR pad.neighborhood_cell LIKE (?)) AND pnc.given_name_code LIKE (?)
       AND pnc.family_name_code LIKE (?) AND person.gender = '#{gender}'
       AND (person.birthdate >= ? AND person.birthdate <= ?)","%#{home_district}%",
          "%#{ta}%","%#{home_village}%","%#{given_name_code}%","%#{family_name_code}%",
          start_birthdate,end_birthdate],:group => "person.person_id")

      if people
        people_ids = []
        (people).each do |person|
          people_ids << person.id
        end
      end

    
      #............................................................................
      @dde_search_results = {}
      (PatientService.search_demographics_from_remote(params) || []).each do |data|
        national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
        national_id = data["person"]["value"] if national_id.blank? rescue nil
        national_id = data["npid"]["value"] if national_id.blank? rescue nil
        national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil
                                                                                
        next if national_id.blank?
        results = PersonSearch.new(national_id)
        results.national_id = national_id
        results.current_residence = data["person"]["data"]["addresses"]["city_village"]
        results.person_id = 0
        results.home_district = data["person"]["data"]["addresses"]["address2"]
        results.neighborhood_cell = data["person"]["data"]["addresses"]["neighborhood_cell"]
        results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
        results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
        gender = data["person"]["data"]["gender"]
        results.occupation = data["person"]["data"]["occupation"]
        results.sex = (gender == 'M' ? 'Male' : 'Female')
        results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
        results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
        results.birthdate = (data["person"]["data"]["birthdate"]).to_date
        results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
        @dde_search_results[results.national_id] = results
        break
      end if create_from_dde_server
      #............................................................................
      #if params
      if not people_ids.blank? or not @dde_search_results.blank?
        redirect_to :action => :create_confirm , :people_ids => people_ids ,
          :user_entered_params => @parameters and return
      end
    end

    hiv_session = false
    if current_program_location == "HIV program"
      hiv_session = true
    end
    success = false

    Person.session_datetime = session[:datetime].to_date rescue Date.today
    identifier = params[:identifier] rescue nil

    if identifier.blank?
      identifier = params[:person][:patient][:identifiers]['National id']
    end rescue nil

    if create_from_dde_server
      unless identifier.blank?
        params[:person].merge!({"identifiers" => {"National id" => identifier}})
        success = true
        person = PatientService.create_from_form(params[:person])
        if identifier.length != 6
          patient = DDEService::Patient.new(person.patient)
          national_id_replaced = patient.check_old_national_id(identifier)
        end
      else
        person = PatientService.create_patient_from_dde(params)
        success = true
      end

      #If we are creating from DDE then we must create a footprint of the just created patient to
      #enable future
      DDEService.create_footprint(PatientService.get_patient(person).national_id, "BART2 - #{BART_VERSION}")
    

      #for now BART2 will use BART1 for patient/person creation until we upgrade BART1 to 2
      #if GlobalProperty.find_by_property('create.from.remote') and property_value == 'yes'
      #then we create person from remote machine
    elsif create_from_remote
      person_from_remote = PatientService.create_remote_person(params)
      person = PatientService.create_from_form(person_from_remote["person"]) unless person_from_remote.blank?

      if !person.blank?
        success = true
        PatientService.get_remote_national_id(person.patient)
      end
    else
      success = true
      params[:person].merge!({"identifiers" => {"National id" => identifier}}) unless identifier.blank?
      person = PatientService.create_from_form(params[:person])
    end

    if params[:person][:patient] && success
      PatientService.patient_national_id_label(person.patient)
      unless (params[:relation].blank?)
        redirect_to search_complete_url(person.id, params[:relation]) and return
      else
      if  ! params[:guardian_present].blank?
        new_encounter = {"encounter_datetime"=> (session[:datetime] rescue Date.today),
        "encounter_type_name"=>"HIV RECEPTION",
        "patient_id"=> person.id,
        "provider_id"=> current_user.id}

       encounter = Encounter.new(new_encounter)
       encounter.encounter_datetime = session[:datetime] rescue Date.today
       encounter.save

      reason_obs = {}
      reason_obs[:concept_name] = 'GUARDIAN PRESENT'
      reason_obs[:encounter_id] = encounter.id
      reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
      reason_obs[:person_id] ||= encounter.patient_id
      reason_obs['value_coded_or_text'] = params[:guardian_present]
      Observation.create(reason_obs)

      reason_obs = {}
      reason_obs[:concept_name] = 'PATIENT PRESENT'
      reason_obs[:encounter_id] = encounter.id
      reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
      reason_obs[:person_id] ||= encounter.patient_id
      reason_obs['value_coded_or_text'] = "YES"
      Observation.create(reason_obs)
      end
      if  params[:guardian_present] == "YES"
      redirect_to "/relationships/search?patient_id=#{person.id}&return_to=/people/redirections?person_id=#{person.id}" and return
      else
      redirect_to "/people/redirections?person_id=#{person.id}" and return
     end
        #raise use_filing_number.to_yaml
       
      end
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end

  def redirections
        person = Person.find(params[:person_id])
        hiv_session = false
        if current_program_location == "HIV program"
            hiv_session = true
        end
       if use_filing_number and hiv_session

          PatientService.set_patient_filing_number(person.patient)
          archived_patient = PatientService.patient_to_be_archived(person.patient)
          message = PatientService.patient_printing_message(person.patient,archived_patient,creating_new_patient = true)
          unless message.blank?
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}" , next_task(person.patient),message,true,person.id)
          else
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient))
          end
        else
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
        end
  end

  def set_datetime
    if request.post?
      unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
        # set for 1 second after midnight to designate it as a retrospective date
        date_of_encounter = Time.mktime(params[:set_year].to_i,
					params[:set_month].to_i,
					params[:set_day].to_i,0,0,1)
        session[:datetime] = date_of_encounter #if date_of_encounter.to_date != Date.today
      end
      session[:stage_patient] = ""
      unless params[:id].blank?
        redirect_to next_task(Patient.find(params[:id])) 
      else
        redirect_to :action => "index"
      end
    end
    @patient_id = params[:id]
  end

  def reset_datetime
    session[:datetime] = nil
    session[:stage_patient] = ""
    if params[:id].blank?
      redirect_to :action => "index" and return
    else
      redirect_to "/patients/show/#{params[:id]}" and return
    end
  end

  def find_by_arv_number
    if request.post?
      redirect_to :action => 'search' ,
        :identifier => "#{PatientIdentifier.site_prefix}-ARV-#{params[:arv_number]}" and return
    end
  end

  def find_by_tb_number
    if request.post?
      numbers_array = params[:tb_number].gsub(/\s+/, "").chars.each_slice(4).map(&:join)
      x = numbers_array.length - 1
      year = numbers_array[0].to_i
      surfix = ""
      (1..x).each { |i| surfix = "#{surfix}#{numbers_array[i].squish}" }
      if year > Date.today.year || surfix.to_i < 1
        render :template => "people/find_by_tb_number" and return
      end

      tb_number = "#{params[:tb_prefix].upcase}-TB #{year} #{surfix.to_i}"
      redirect_to :action => 'search' ,
        :identifier => tb_number and return
    end
  end

  def correct_tb_numbers
    @identifier_types = ["Legacy Pediatric id","National id","Legacy National id"]
      identifier_types = PatientIdentifierType.find(:all,
        :conditions=>["name IN (?)",@identifier_types]
      ).collect{| type |type.id }

      @patient = Patient.find(params[:patient_id] || params[:id])
    if request.post?
      current_date = Date.today
      current_date = session[:datetime].to_date if !session[:datetime].blank?

      prefix = params[:tb_prefix].upcase
      session_date = "#{prefix}-TB #{current_date.year.to_s}"
      patient_exists = PatientIdentifier.find(:all,
        :conditions => ['identifier_type = ?
                                         AND patient_id = ? AND voided = 0', params[:identifiers][0][:identifier_type].to_i , params[:patient_id]]).first
       
        if ! patient_exists.blank?
          patient_exists.voided = 1
          patient_exists.save
        end
        if params[:name].upcase == "VOIDING PERMANENTLY"
          redirect_to "/patients/tb_treatment_card?patient_id=#{params[:patient_id]}" and return
        end
        if !params[:number].blank?
           numbers_array = params[:number].gsub(/\s+/, "").chars.each_slice(4).map(&:join)
           x = numbers_array.length - 1
           year = numbers_array[0].to_i
           surfix = ""
           (1..x).each { |i| surfix = "#{surfix}#{numbers_array[i].squish}" }
            if year > Date.today.year || surfix.to_i < 1
                return
            end
          patient_number = "#{prefix}-TB #{year} #{surfix.to_i}"
          patient_exists = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
                WHERE REPLACE(identifier, ' ', '') = REPLACE('#{patient_number}', ' ', '') AND voided =0 ").first

          if ! patient_exists.blank?
              patient_exists.identifier = patient_number
              patient_exists.save!
          else
              pat = PatientIdentifier.new()
              pat.patient_id = params[:patient_id]
              pat.identifier = patient_number
              pat.identifier_type = params[:identifiers][0][:identifier_type].to_i
              pat.location_id = params[:identifiers][0][:location_id].to_i
              pat.creator = 1
              pat.save!
          end
          redirect_to "/patients/tb_treatment_card?patient_id=#{params[:patient_id]}" and return
        end
        type = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
																						WHERE identifier_type = #{params[:identifiers][0][:identifier_type].to_i} and identifier LIKE '%#{session_date}%'
																						AND voided = 0 ORDER BY patient_identifier_id DESC")
        type = type.first.identifier.split(" ") rescue ""
        if type.include?(current_date.year.to_s)
          surfix = (type.last.to_i + 1)
        else
          surfix = 1
        end
        pat = PatientIdentifier.new()
        pat.patient_id = params[:patient_id]
        pat.identifier = "#{session_date} #{surfix}"
        pat.identifier_type = params[:identifiers][0][:identifier_type].to_i
        pat.location_id = params[:identifiers][0][:location_id].to_i
        pat.creator = 1
        pat.save!

      redirect_to "/patients/tb_treatment_card?patient_id=#{params[:patient_id]}" and return
    end
  end
  
  # List traditional authority containing the string given in params[:value]
  def traditional_authority
    district_id = District.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "%#{params[:search_string]}%", district_id]

    traditional_authorities = TraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value='#{t_a.name}'>#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') + "<li value='Other'>Other</li>" and return
  end

  # Regions containing the string given in params[:value]
  def region_of_origin
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'region_id')
    regions = regions.map do |r|
      "<li value='#{r.name}'>#{r.name}</li>"
    end
    render :text => regions.join('')  and return
  end
  
  def region
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'region_id')
    regions = regions.map do |r|
      if r.name != "Foreign"
        "<li value='#{r.name}'>#{r.name}</li>"
      end
    end
    render :text => regions.join('')  and return
  end

  #countries
   def country
    country_conditions = ["name LIKE (?)", "%#{params[:search_string]}%"]

    countries = Country.find(:all,:conditions => country_conditions, :order => 'name')
    countries = countries.map do |r|
        "<li value='#{r.name}'>#{r.name}</li>"
    end
    render :text => countries.join('')  and return
  end
  # Districts containing the string given in params[:value]
  def district
    region_id = Region.find_by_name("#{params[:filter_value]}").id
    region_conditions = ["name LIKE (?) AND region_id = ? ", "#{params[:search_string]}%", region_id]

    districts = District.find(:all,:conditions => region_conditions, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

  def tb_initialization_district
    districts = District.find(:all, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

	def tb_initialization_location
    locations = Location.find_by_sql("SELECT name FROM location WHERE description like '%Health Facility' AND name LIKE '#{params[:search_string]}%'order by name LIMIT 10")
    locations = locations.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => locations.join('') + "<li value='Other'>Other</li>" and return
  end
	# Villages containing the string given in params[:value]
  def village
    traditional_authority_id = TraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "%#{params[:search_string]}%", traditional_authority_id]

    villages = Village.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value='" + v.name + "'>" + v.name + "</li>"
    end
    render :text => villages.join('') + "<li value='Other'>Other</li>" and return
  end
  
  # Landmark containing the string given in params[:value]
  def landmark
    landmarks = PersonAddress.find(:all, :select => "DISTINCT address1" , :conditions => ["city_village = (?) AND address1 LIKE (?)", "#{params[:filter_value]}", "#{params[:search_string]}%"])
    landmarks = landmarks.map do |v|
      "<li value='#{v.address1}'>#{v.address1}</li>"
    end
    render :text => landmarks.join('') + "<li value='Other'>Other</li>" and return
  end

=begin
  #This method was taken out of encounter model. It is been used in
  #people/index (view) which seems not to be used at present.
  def count_by_type_for_date(date)
    # This query can be very time consuming, because of this we will not consider
    # that some of the encounters on the specific date may have been voided
    ActiveRecord::Base.connection.select_all("SELECT count(*) as number, encounter_type FROM encounter GROUP BY encounter_type")
    todays_encounters = Encounter.find(:all, :include => "type", :conditions => ["DATE(encounter_datetime) = ?",date])
    encounters_by_type = Hash.new(0)
    todays_encounters.each{|encounter|
      next if encounter.type.nil?
      encounters_by_type[encounter.type.name] += 1
    }
    encounters_by_type
  end
=end

  def art_info_for_remote(national_id)

    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}

    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","HIV CLINIC CONSULTATION","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','HIV CLINIC REGISTRATION']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'


      art_start_date = PatientService.patient_art_start_date(patient.id).strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

      program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'

      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
        'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end

  def art_info_for_remote(national_id)
    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}
    
    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","HIV CLINIC CONSULTATION","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','HIV CLINIC REGISTRATION']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      art_start_date = patient.art_start_date.strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

			program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'
      
      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
				'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end
  
  def occupations
    ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
			'Student','Security guard','Domestic worker', 'Police','Office worker',
			'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
  end

  def edit
    # only allow these fields to prevent dangerous 'fields' e.g. 'destroy!'
    valid_fields = ['birthdate','gender']
    unless valid_fields.include? params[:field]
      redirect_to :controller => 'patients', :action => :demographics, :id => params[:id]
      return
    end

    @person = Person.find(params[:id])
    if request.post? && params[:field]
      if params[:field]== 'gender'
        @person.gender = params[:person][:gender]
      elsif params[:field] == 'birthdate'
        if params[:person][:birth_year] == "Unknown"
          @person.set_birthdate_by_age(params[:person]["age_estimate"])
        else
          PatientService.set_birthdate(@person, params[:person]["birth_year"],
						params[:person]["birth_month"],
						params[:person]["birth_day"])
        end
        @person.birthdate_estimated = 1 if params[:person]["birthdate_estimated"] == 'true'
        @person.save
      end
      @person.save
      redirect_to :controller => :patients, :action => :edit_demographics, :id => @person.id
    else
      @field = params[:field]
      @field_value = @person.send(@field)
    end
  end
  
  def dde_search
    # result = '[{"person":{"created_at":"2012-01-06T10:08:37Z","data":{"addresses":{"state_province":"Balaka","address2":"Hospital","city_village":"New Lines Houses","county_district":"Kalembo"},"birthdate":"1989-11-02","attributes":{"occupation":"Police","cell_phone_number":"0999925666"},"birthdate_estimated":"0","patient":{"identifiers":{"diabetes_number":""}},"gender":"M","names":{"family_name":"Banda","given_name":"Laz"}},"birthdate":"1989-11-02","creator_site_id":"1","birthdate_estimated":false,"updated_at":"2012-01-06T10:08:37Z","creator_id":"1","gender":"M","id":1,"family_name":"Banda","given_name":"Laz","remote_version_number":null,"version_number":"0","national_id":null}}]'
    
    @dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    
    @dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    
    @dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    
    url = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}" + 
      "/people/find.json?given_name=#{params[:given_name]}" + 
      "&family_name=#{params[:family_name]}&gender=#{params[:gender]}"
    
    result = RestClient.get(url)
    render :text => result, :layout => false
  end

  def demographics
    @person = Person.find(params[:id])
		@patient_bean = PatientService.get_patient(@person)
		render :layout => 'menu'
  end

  def duplicates
    @duplicates = []
    people = PatientService.person_search(params[:search_params])
    people.each do |person|
      @duplicates << PatientService.get_patient(person)
    end unless people == "found duplicate identifiers"

    if create_from_dde_server
      @remote_duplicates = []
      PatientService.search_from_dde_by_identifier(params[:search_params][:identifier]).each do |person|
        @remote_duplicates << PatientService.get_dde_person(person)
      end
    end

    @selected_identifier = params[:search_params][:identifier]
    render :layout => 'menu'
  end

  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def remote_duplicates
    if params[:patient_id]
      @primary_patient = PatientService.get_patient(Person.find(params[:patient_id]))
    else
      @primary_patient = nil
    end

    @dde_duplicates = []
    if create_from_dde_server
      PatientService.search_from_dde_by_identifier(params[:identifier]).each do |person|
        @dde_duplicates << PatientService.get_dde_person(person)
      end
    end

    if @primary_patient.blank? and @dde_duplicates.blank?
      redirect_to :action => 'search',:identifier => params[:identifier] and return
    end
    render :layout => 'menu'
  end

  def reassign_national_identifier
    patient = Patient.find(params[:person_id])
    if create_from_dde_server
      passed_params = PatientService.demographics(patient.person)
      new_npid = PatientService.create_from_dde_server_only(passed_params)
      npid = PatientIdentifier.new()
      npid.patient_id = patient.id
      npid.identifier_type = PatientIdentifierType.find_by_name('National ID')
      npid.identifier = new_npid
      npid.save
    else
      PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    end
    npid = PatientIdentifier.find(:first,
      :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.voided_by = current_user.id
    npid.save

    print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
  end

  def create_person_from_dde
    person = DDEService.get_remote_person(params[:remote_person_id])

    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def demographics_remote
    identifier = params[:person][:patient][:identifiers]["national_id"] rescue nil
    identifier = params["person"]["patient"]["identifiers"]["National id"] if identifier.nil?
    people = PatientService.search_by_identifier(identifier)
    render :text => "" and return if people.blank?
    render :text => PatientService.remote_demographics(people.first).to_json rescue nil
    return
  end

  def area_graph_adults
    @patient_bean = PatientService.get_patient(Person.find(params[:id]))
    weight_obs = Observation.find(:all,:joins =>"INNER JOIN encounter USING(encounter_id)",
      :conditions =>["patient_id=? AND encounter_type=?
      AND concept_id=?",params[:id],EncounterType.find_by_name('Vitals').id,
        ConceptName.find_by_name('WEIGHT (KG)').concept_id],
      :group =>"Date(encounter_datetime)",
      :order =>"encounter_datetime DESC")
    
    @start_date = weight_obs.last.obs_datetime.to_date rescue Date.today
    @weights = [] ; weights = {} ; count = 1
    (weight_obs || []).each do |weight|
      next if weight.value_numeric.blank?
      weights[weight.obs_datetime] = weight.value_numeric
      break if count > 12  
      count+=1  
    end
    (weights || {}).sort{|a,b|a[0].to_date <=> b[0].to_date}.each do |date,weight|
      @weights << [date.to_date.strftime('%d.%b.%y') , weight]
    end

    @weights = @weights.to_json
    render :partial => "area_chart_adults" and return
  end

	private
  
	def search_complete_url(found_person_id, primary_person_id)
		unless (primary_person_id.blank?)
			# Notice this swaps them!
			new_relationship_url(:patient_id => primary_person_id, :relation => found_person_id)
		else
			#
			# Hack reversed to continue testing overnight
			#
			# TODO: This needs to be redesigned!!!!!!!!!!!
			#
			#url_for(:controller => :encounters, :action => :new, :patient_id => found_person_id)
			patient = Person.find(found_person_id).patient
			show_confirmation = CoreService.get_global_property_value('show.patient.confirmation').to_s == "true" rescue false
			if show_confirmation
				url_for(:controller => :people, :action => :confirm , :found_person_id =>found_person_id)
			else
				next_task(patient)
			end
		end
	end

  def cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)
                                                                                
    # This code which better accounts for leap years                            
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)
                                                                                
    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate                                                      
    estimate = birthdate_estimated == 1                                         
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end                                                                           
                                                                                
  def birthdate_formatted(birthdate,birthdate_estimated)                        
    if birthdate_estimated == 1                                                 
      if birthdate.day == 1 and birthdate.month == 7                            
        birthdate.strftime("??/???/%Y")                                         
      elsif birthdate.day == 15                                                 
        birthdate.strftime("??/%b/%Y")                                          
      elsif birthdate.day == 1 and birthdate.month == 1                         
        birthdate.strftime("??/???/%Y")                                         
      end                                                                       
    else                                                                        
      birthdate.strftime("%d/%b/%Y")                                            
    end                                                                         
  end
end
 
