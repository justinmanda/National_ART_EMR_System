require File.dirname(__FILE__) + '/../test_helper'

class ApplicationControllerTest < ActionController::TestCase
  fixtures :global_property, :patient

  def setup  
    @controller = ApplicationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @patient = patient(:evan)   
  end

  context "Application controller" do
  
    context "helpers" do
      
      include ApplicationHelper
      
      should "determine which stylesheet to use for the interface" do
        assert_equal fancy_or_high_contrast_touch, "touch.css"
        GlobalProperty.make(:property => 'interface', :property_value => 'fancy')
        assert_equal fancy_or_high_contrast_touch, "touch-fancy.css"          
      end
    end
    
    should "get the generic locations" do
      get :generic_locations
      assert_response :redirect
    end

    should "get the the patients next task" do
      get :next_task, {:patient => @patient}
      assert_response :redirect
    end

  end
end
