class PropertiesController < GenericPropertiesController
	def export_cohort_data
		 if request.post? and not params[:export_cohort_data].blank?
			 session["export.cohort.data"] = params[:export_cohort_data]
      redirect_to '/clinic' and return
    end
	end

	def staging_options
			global_setting = GlobalProperty.find_by_property("use.extended.staging.questions")
			global_setting.property_value = "false"
			global_setting.property_value = "true" if params['staging_options'].to_s.match(/extended/i)
			global_setting.save
			redirect_to '/clinic' and return
	end
end
