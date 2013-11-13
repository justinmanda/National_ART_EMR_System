class ProgramsController < GenericProgramsController

  def create_exit_from_care_encounter(given_params)
    states_to_create_encounter_for = []
    concept_set("EXIT FROM CARE").each{|concept| states_to_create_encounter_for << concept.uniq.to_s}
   
    current_state = given_params[:current_state]

    if states_to_create_encounter_for.include? current_state
      new_encounter = {"encounter_datetime"=> given_params[:current_date],
        "encounter_type_name"=>"EXIT FROM HIV CARE",
        "patient_id"=> params[:patient_id],
        "provider_id"=>params[:encounter][:provider_id]}

      encounter = Encounter.new(new_encounter)
      encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
      encounter.save

      reason_obs = {}
      reason_obs[:concept_name] = 'REASON FOR EXITING CARE'
      reason_obs[:encounter_id] = encounter.id
      reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
      reason_obs[:person_id] ||= encounter.patient_id
      reason_obs['value_coded_or_text'] = current_state
      Observation.create(reason_obs)

      reason_obs = {}
      reason_obs[:concept_name] = 'PATIENT TRACKING STATE'
      reason_obs[:encounter_id] = encounter.id
      reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
      reason_obs[:person_id] ||= encounter.patient_id
      reason_obs['value_numeric'] = given_params[:patient_state_id]
      Observation.create(reason_obs)

      date_obs = {}
      date_obs[:concept_name] = 'DATE OF EXITING CARE'
      date_obs[:encounter_id] = encounter.id
      date_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
      date_obs[:person_id] ||= encounter.patient_id
      date_obs['value_datetime'] = given_params[:current_date]
      Observation.create(date_obs)

      if current_state.upcase == 'PATIENT TRANSFERRED OUT'
        observation = {}
        observation[:concept_name] = 'TRANSFER OUT TO'
        observation[:encounter_id] = encounter.id
        observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
        observation[:person_id] ||= encounter.patient_id
        observation['value_numeric'] = params[:transfer_out_location_id]
        Observation.create(observation)
      end
      #rebuild_program_states(given_params[:patient_program_id], given_params[:encounter][:patient_id])
    end
  end

  def rebuild_program_states(patient_program_id, patient_id)

		#raise patient_program_id.to_yaml
    current_patient_program = PatientProgram.find(patient_program_id)
    # gather initial data for the particular program required data
    program_id = current_patient_program.program_id
    location_id = current_patient_program.location_id
    initial_date = Date.today
    program_states_to_void = [2,3,6,7] #transferred out, dead, treatment stopped, on arvs
    pre_art_state = 1

    # find patient
    patient = Patient.find(patient_id)

    # delete the program associated states
    current_patient_program.patient_states.each do |state|
      state.void if program_states_to_void.include? state.state
    end

    pre_art_state_exists = true if current_patient_program.patient_states.map(&:state).include? pre_art_state
    # create pre ART state for the program
    if ! pre_art_state_exists == true
      initial_patient_state = current_patient_program.patient_states.build(
        :state => 1, #TODO find a better way of getting the this state rather than hard coding
        :start_date => initial_date,
        :creator => User.current.user_id)
      initial_patient_state.save
    else 
      #ensure that initial state is known, so that we can assign 
      #end date of the beginning of the on arv state
      current_patient_program.patient_states.each do |state|
        initial_patient_state = state if state.state == pre_art_state
      end
    end

    # create on ART state if the patient has any art dispensation
    #TODO check if the patient has any art dispensation, and get the date of the earliest start date

    date_of_first_dispensation = PatientService.date_of_first_dispensation(patient) rescue nil
   
    if ! date_of_first_dispensation.nil?
      on_arv_state = current_patient_program.patient_states.build(
        :state => 7, #TODO find a better way of getting the this state rather than hard coding
        :start_date => date_of_first_dispensation,
        :creator => User.current.user_id) #TODO use the date obtained from the check above
      on_arv_state.save

      # update the start date of the pre ART state from
      if ! initial_patient_state.nil?
        initial_patient_state[:start_date] = date_of_first_dispensation
        initial_patient_state[:end_date] = date_of_first_dispensation
        initial_patient_state.save
      end
      patient_on_arvs = true
    end
    # set patient deathdate and dead pointer to nil

    patient.person[:death_date] = "NULL"
    patient.person[:dead] = 0
    patient.person.save

    exit_from_care_encounter_type = EncounterType.find_by_name("EXIT FROM HIV CARE").id
    exit_from_care_encounter = Encounter.find(:all,
      :conditions => ["encounter_type = ? AND patient_id = ? AND voided = 0",
        exit_from_care_encounter_type, patient.patient_id]
    )

    reason_for_exiting_care = ConceptName.find_by_name("REASON FOR EXITING CARE").concept_id
    date_of_exiting_care = ConceptName.find_by_name("DATE OF EXITING CARE").concept_id

		#raise exit_from_care_encounter.to_yaml
    exit_from_care_encounter.each do |encounter| #loop through the encounters of exit from care encounters
      exit_from_care_type = ''
      exit_from_care_date = ''

      encounter.observations.each do |obs| #loop through the observations to get the individual values of the exit from care observation
        if obs.concept_id == reason_for_exiting_care
          exit_from_care_type = ConceptName.find_by_concept_name_id(obs.value_coded_name_id).name
        elsif obs.concept_id == date_of_exiting_care
          exit_from_care_date = obs.value_datetime
        end
      end #end of obs loop
			
			

      if exit_from_care_type.to_s.upcase == "PATIENT DIED" #add patient_died state
        #show patient as died in patient_table
        patient.person[:death_date] = exit_from_care_date
        patient.person[:dead] = 1
        patient.person.save

        dead_patient_state = current_patient_program.patient_states.build(
          :state => 3, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => User.current.user_id)
        dead_patient_state.save

      elsif exit_from_care_type.to_s.upcase == "PATIENT TRANSFERRED OUT"

        transfer_out_patient_state = current_patient_program.patient_states.build(
          :state => 2, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => User.current.user_id)
        transfer_out_patient_state.save

      elsif exit_from_care_type.to_s.upcase == "TREATMENT STOPPED"

        stopped_patient_state = current_patient_program.patient_states.build(
          :state => 6, #TODO find a better way of getting the this state rather than hard coding
          :start_date => exit_from_care_date,
          :creator => User.current.user_id)
        stopped_patient_state.save      
      end
			
      #update the the on_arvs state, append the exit from care date if the patient is on arvs
			if ! on_arv_state.nil?
				on_arv_state[:end_date] = exit_from_care_date.to_date
				on_arv_state.save
			end

      #update the end date for the patient program    
      current_patient_program.date_completed = exit_from_care_date
      current_patient_program.save

      #check for dispensation after the exit from care state
      next_dispensation_date = PatientService.date_dispensation_date_after(patient, exit_from_care_date.to_date)
			
      if ! next_dispensation_date.nil?
        #reset the end date of the program
        current_patient_program.date_completed = 'NULL'
        current_patient_program.save

        #create On ARVs state

        on_arv_state = current_patient_program.patient_states.build(
          :state => 7, #TODO find a better way of getting the this state rather than hard coding
          :start_date => next_dispensation_date,
          :creator => User.current.user_id) #TODO use the date obtained from the check above
        on_arv_state.save

      end
    end #end of encounters loop

  end

  def exitcare

    @exit_from_care_state = params[:exit_state]
    @patient = Patient.find(params[:patient_id])
    hiv_program_id = Program.find_by_name("HIV PROGRAM").id
    patient_program = PatientProgram.find(:all,
      :conditions => ["patient_id = ? and program_id = ?",
        params[:patient_id], hiv_program_id]).first rescue nil


    @patient_program_id = patient_program.patient_program_id

  end

  def exitcarestates
    required_states = []
    concept_set("EXIT FROM CARE").each{|concept| required_states << concept.uniq.to_s}

    @states = ProgramWorkflowState.all(:conditions => ['program_workflow_id = ?', params[:workflow]], :include => :concept)

    @names = @states.map{|state|
      next if ! required_states.include? state.concept.fullname
      name = state.concept.concept_names.typed("SHORT").first.name rescue state.concept.fullname
      next if name.blank?
      "<li value='#{state.id}'>#{name}</li>" unless name == params[:current_state]
    }
    render :text => @names.join('')
  end

  def update_exitcare
    
    patient_program = PatientProgram.find(params[:patient_program_id])
    #we don't want to have more than one open states - so we have to close the current active on before opening/creating a new one

    current_active_state = patient_program.patient_states.last rescue []
    current_active_state.end_date = params[:current_date].to_date rescue session[:datetime] rescue Date.today
    #raise current_active_state.to_s.to_yaml
    # set current location via params if given
    Location.current_location = Location.find(params[:location]) if params[:location]
    #state_concept = ConceptName.find_by_name(params[:current_state]).concept
    state_concept = ConceptName.find_all_by_name(params[:current_state])
    state = ProgramWorkflowState.find(:first, :conditions => ["concept_id IN (?)",state_concept.map{|c|c.concept_id}] ).program_workflow_state_id
=begin
    program_workflow_state = ProgramWorkflowState.find(:first, 
      :joins => "INNER JOIN program_workflow USING (program_workflow_id) INNER JOIN program USING (program_id)",
      :conditions => ["program_workflow.program_id = ? AND program_workflow_state.concept_id = ?",
                       patient_program.program_id, state_concept.id])
    
    patient_state = patient_program.patient_states.build(
      :state => program_workflow_state.id,
      :start_date => params[:current_date])
=end
    patient_state = patient_program.patient_states.build(
      :state => state,
      :start_date => params[:current_date])
    if patient_state.save
     
      # Close and save current_active_state if a new state has been created
      current_active_state.save!
      
=begin
if patient_state.program_workflow_state.concept.fullname.upcase == 'PATIENT TRANSFERRED OUT'
encounter = Encounter.new(params[:encounter])
encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
encounter.save

(params[:observations] || [] ).each do |observation|
#for now i do this
obs = {}
obs[:concept_name] = observation[:concept_name]
obs[:value_coded_or_text] = observation[:value_coded_or_text]
obs[:encounter_id] = encounter.id
obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
obs[:person_id] ||= encounter.patient_id
Observation.create(obs)
end

observation = {}
observation[:concept_name] = 'TRANSFER OUT TO'
observation[:encounter_id] = encounter.id
observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
observation[:person_id] ||= encounter.patient_id
#observation[:value_text] = params[:transfer_out_location_id]
observation['value_text'] = Location.find(params[:transfer_out_location_id]).name.to_s rescue ""
Observation.create(observation)
end
=end

      updated_state = patient_state.program_workflow_state.concept.fullname

     
      #disabled redirection during import in the code below
      # Changed the terminal state conditions from hardcoded ones to terminal indicator from the updated state object
      if patient_state.program_workflow_state.terminal == 1
        #the following code updates the person table to died yes if the state is Died/Death
        if updated_state.match(/DIED/i)
          person = patient_program.patient.person
          person.dead = 1
          unless params[:current_date].blank?
            person.death_date = params[:current_date].to_date
          end
          person.save

          #updates the state of all patient_programs to patient died and save the
          #end_date of the last active state.
          current_programs = PatientProgram.find(:all,:conditions => ["patient_id = ?",@patient.id])
          current_programs.each do |program|
            if patient_program.to_s != program.to_s
              current_active_state = program.patient_states.last
              current_active_state.end_date = params[:current_date].to_date

              Location.current_location = Location.find(params[:location]) if params[:location]

              patient_state = program.patient_states.build(
                :state => state,
                :start_date => params[:current_date])
              if patient_state.save
                current_active_state.save

                # date_completed = session[:datetime].to_time rescue Time.now()
                date_completed = params[:current_date].to_date rescue Time.now()
                PatientProgram.update_all "date_completed = '#{date_completed.strftime('%Y-%m-%d %H:%M:%S')}'",
                  "patient_program_id = #{program.patient_program_id}"
              end
            end
          end
        end

        # date_completed = session[:datetime].to_time rescue Time.now()
        date_completed = params[:current_date].to_date rescue Time.now()
        PatientProgram.update_all "date_completed = '#{date_completed.strftime('%Y-%m-%d %H:%M:%S')}'",
          "patient_program_id = #{patient_program.patient_program_id}"
      else
        person = patient_program.patient.person
        person.dead = 0
        person.save
        date_completed = nil
        PatientProgram.update_all "date_completed = NULL",
          "patient_program_id = #{patient_program.patient_program_id}"
      end
      params[:patient_state_id] = patient_state.patient_state_id unless patient_state.patient_state_id.blank?
      create_exit_from_care_encounter(params)
      #print the transfer out label if patient was transfered out
      if patient_state.program_workflow_state.concept.fullname.upcase == 'PATIENT TRANSFERRED OUT'
        print_and_redirect("/patients/transfer_out_label?patient_id=#{params[:patient_id]}", "/patients/exitcare_dashboard/#{params[:patient_id]}")
      else
        redirect_to :controller => :patients, :action => :exitcare_dashboard, :id => params[:patient_id]
      end

    else
      redirect_to :controller => :patients, :action => :exitcare_dashboard, :id => params[:patient_id],:error => "Unable to update state"
    end
  end

  def void_exitcare
    hiv_program_id = Program.find_by_name("HIV PROGRAM").id
    patient_program = PatientProgram.find(:all,
      :conditions => ["patient_id = ? AND program_id = ? AND voided = 0",
        params[:patient_id], hiv_program_id]).first rescue nil
    if ! patient_program.nil?
      rebuild_program_states(patient_program.patient_program_id, params[:patient_id])
    end

  end

	def show
		tb_states = ["currently in treatment", "patient cured", "patient transferred out", "regimen failure","treatment complete","patient died"]
    if params[:show_non_terminal_states_only].to_s == true.to_s
      @states = ProgramWorkflowState.all(:conditions => ['program_workflow_id = ? AND terminal = 0', params[:workflow]], :include => :concept)
    else
      @states = ProgramWorkflowState.all(:conditions => ['program_workflow_id = ?', params[:workflow]], :include => :concept)
    end

    @names = @states.map{|state|

      name = state.concept.concept_names.typed("SHORT").first.name rescue state.concept.fullname
      next if name.blank?
			if tb_states.include?(name.downcase.to_s)
        "<li value='#{state.id}'>#{name}</li>" unless name == params[:current_state]
			end
    }
    render :text => @names.join('')
  end

end
