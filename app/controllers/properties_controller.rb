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

  def filing_number
		 if request.post?
			filing_limit = GlobalProperty.find_by_property("filing.number.limit") rescue nil
			 if filing_limit.nil?
						filing_limit = GlobalProperty.new
						filing_limit.property = "filing.number.limit"
            filing_limit.description = "Maximum number for archiving of files to begin"
						filing_limit.property_value = params[:filing_number]
						filing_limit.save
			 else
           filing_limit = GlobalProperty.find_by_property("filing.number.limit")
           filing_limit.property_value = params[:filing_number]
           filing_limit.save
			 end
      redirect_to '/clinic' and return
    end
	end
end
