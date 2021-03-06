require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class CorrectRefrigerantUnderchargeTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = CorrectRefrigerantUndercharge.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
  end

  def test_is_applicable_to_test_models
  
	["LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm", "MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName)
	end
  end
    
  def test_is_not_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("NA", result.value.valueName)
	end
  end
    
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "No qualified DX cooling or heating objects are present in this model. The measure is not applicable."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Coil Cooling Water To Air Heat Pump Equation Fit object renamed DataCenter_basement_ZN_6 ZN PSZ Data Center Water-to-Air HP Clg Coil +30 Percent undercharge has had initial COP value of 3.4 derated to a COP value of 3.0253200000000002 representing a 30 percent by volume refrigerant undercharge scenario."})
	refute_nil(result.info.find {|m| m.logMessage == "Coil Heating Water To Air Heat Pump Equation Fit object renamed DataCenter_bot_ZN_6 ZN PSZ Data Center Water-to-Air HP Htg Coil +30 Percent undercharge has had initial COP value of 4.2 derated to a COP value of 3.85392 representing a 30 percent by volume refrigerant undercharge scenario."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Two Speed DX Cooling Coil object renamed 5 Zone PVAV Clg Coil 625kBtu/hr 10.0EER +30 Percent undercharge had initial high speed COP value of 3.46587912526969 derated to a COP value of 3.08393924566497 and an initial lowspeed COP value of 3.46587912526969 derated to a COP value of 3.08393924566497 representing a 30 percent by volume refrigerant undercharge scenario."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Two Speed DX Cooling Coil object renamed PVAV_POD_2 Clg Coil 425kBtu/hr 9.5EER +30 Percent undercharge had initial high speed COP value of 3.29940335082439 derated to a COP value of 2.9358091015635424 and an initial lowspeed COP value of 3.29940335082439 derated to a COP value of 2.9358091015635424 representing a 30 percent by volume refrigerant undercharge scenario."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Two Speed DX Cooling Coil object renamed PSZ-AC_2-6 2spd DX AC Clg Coil 492kBtu/hr 10.0EER +30 Percent undercharge had initial high speed COP value of 3.46587912526969 derated to a COP value of 3.08393924566497 and an initial lowspeed COP value of 3.46587912526969 derated to a COP value of 3.08393924566497 representing a 30 percent by volume refrigerant undercharge scenario."})
  end
    
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Single Speed DX Cooling Coil object renamed CorridorFlr4 ZN PTAC 1spd DX AC Clg Coil +30 Percent undercharge had initial COP value of 3.0 derated to a COP value of 2.6694 representing a 30 percent by volume refrigerant undercharge scenario."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "Single Speed DX Cooling Coil object renamed PSZ-AC-5 1spd DX HP Clg Coil +30 Percent undercharge had initial COP value of 3.0 derated to a COP value of 2.6694 representing a 30 percent by volume refrigerant undercharge scenario."})
  end
    
  def applytotestmodel(model_file)
  
	measure = CorrectRefrigerantUndercharge.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{model_file}")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # Set argument values
    arg_values = {
    "run_measure" => 1
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end    
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    return result, model
  end  
 
end
