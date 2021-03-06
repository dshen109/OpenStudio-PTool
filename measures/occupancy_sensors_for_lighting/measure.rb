# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

#start the measure
class OccupancySensorsForLighting < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Occupancy Sensors For Lighting"
  end

  # human readable description
  def description
    return "This energy efficiency measure (EEM) adjusts the interior lighting power per for affected space types to account for occupant sensors according to Standard 90.1-2010 Table 9.6.2 and Addendum cg Table G3.1(g). Lighting power for affected space types is adjusted by a fixed control factor of 0.05 for multi-level occupancy sensors in breakrooms, conference rooms, offices, restrooms, and stairs. The measure does not change the model unless Space Types use Measure Tags for Standards Space Type and Lights Definitions use either W/area or W/person inputs (an absolute W input is not supported)."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure loops through space types in the model and adjusts the lighting power per area (W/ft2) or lighting power per person (W/person) for affected space types. The measure is not currently able to change the lighting power is specified using the Lighting Level (W) input option."
  end  
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    
    # initialize variables
    affected_space_types = []
    affected_flag = false
    power_tot = 0
    power_tot_new = 0
    control_factor = 0.05 #90.1-2010 Table 9.6.2

    # standards space types
    affected_space_types << "BreakRoom"
    affected_space_types << "Conference"
    affected_space_types << "Office"
    affected_space_types << "Restroom"
    affected_space_types << "Stair"

    # get model objects
    space_types = model.getSpaceTypes

    # DO STUFF
    #TODO account for zone multipliers?
    space_types.each do |st|

      std_spc_typ = st.standardsSpaceType.to_s
      area = st.floorArea
      people = st.getNumberOfPeople(area)
      power = st.getLightingPower(area, people)
      power_tot += power

      #calcualte LPD
      lpd_area = power / area
      lpd_people = power / people

      affected_space_types.each do |ast|

        if ast == std_spc_typ

          #calculate adjustment and new power
          power_adj = power * control_factor
          power_new = power - power_adj

          lpd_area_new = power_new / area
          lpd_people_new = power_new / people

          #set new power
          if st.lightingPowerPerFloorArea.is_initialized

            runner.registerInfo("Adjusting interior lighting power for space type: #{st.name}")
            st.setLightingPowerPerFloorArea(lpd_area_new)

            lpd_area_ip = OpenStudio.convert(lpd_area,"ft^2","m^2").get
            lpd_area_new_ip = OpenStudio.convert(lpd_area_new,"ft^2","m^2").get
            lpd_area_change = (1 - (lpd_area_new / lpd_area)) * 100

            runner.registerInfo("=> Initial interior lighting power = #{lpd_area_ip.round(2)} W/ft2")
            runner.registerInfo("=> Final interior lighting power = #{lpd_area_new_ip.round(2)} W/ft2")
            runner.registerInfo("=> Interior lighting power reduction = #{lpd_area_change.round(0)}%")

          elsif st.lightingPowerPerPerson.is_initialized

            runner.registerInfo("Adjusting interior lighting power for space type: #{st.name}")
            st.setLightingPowerPerPerson(lpd_people_new)

            lpd_people_change = (1 - (lpd_people_new / lpd_people)) * 100

            runner.registerInfo("=> Initial interior lighting power = #{lpd_people} W/person")
            runner.registerInfo("=> Final interior lighting power = #{lpd_people_new} W/person")
            runner.registerInfo("=> Interior lighting power reduction = #{lpd_people_change.round(0)}%")

          else

            runner.registerWarning("Lighting power is specified using Lighting Level (W) for affected space type: #{st.name}")

          end #set new power

          affected_flag = true

        end

      end #affected space types

      # calculate new total lighting power
      power = st.getLightingPower(area, people)
      power_tot_new += power

    end #space types

    # report not applicable
    if affected_flag == false
      runner.registerAsNotApplicable("No affected space types found")
    end

    # report initial condition
    runner.registerInitialCondition("Total interior lighting power = #{power_tot.round(0)} W")

    # report final condition
    runner.registerFinalCondition("Total interior lighting power = #{power_tot_new.round(0)} W")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
OccupancySensorsForLighting.new.registerWithApplication
