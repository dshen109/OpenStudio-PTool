# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class DemandControlVentilationMetalOxideSensors < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Demand Control Ventilation Metal Oxide Sensors"
  end

  # human readable description
  def description
    return "This measure dynamically reduces the amount of outdoor air intake below the design minimum values based on the actual occupancy of the building at each hour.  This reduces the energy needed to heat and cool this outdoor air."
  end

  # human readable description of modeling approach
  def modeler_description
    return "For each AirLoop, check if it is a VAV system, and if DCV is not already enabled, enable it via the Controller:MechanicalVentilation object and also reduce the minimum OA flow rate to zero to enable maximum OA turndown. This measure is currently modeled exactly like typical DCV."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Return N/A if not selected to run
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end    
    



    
    # Loop through all air loops
    # and add DCV if applicable
    air_loops = []
    air_loops_already_dcv = []
    air_loops_dcv_added = []
    model.getAirLoopHVACs.each do |air_loop|
    
      air_loops << air_loop
    
      # DCV Not Applicable for AHUs that already have DCV
      # or that have no OA intake.
      controller_oa = nil
      controller_mv = nil
      if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
        oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
        controller_oa = oa_system.getControllerOutdoorAir      
        controller_mv = controller_oa.controllerMechanicalVentilation
        if controller_mv.demandControlledVentilation == true
          air_loops_already_dcv << air_loop
          runner.registerInfo("DCV not applicable to '#{air_loop.name}' because DCV already enabled.")
          next
        end
      else
        runner.registerInfo("DCV not applicable to '#{air_loop.name}' because it has no OA intake.")
        next
      end

      # DCV Not Applicable to constant volume systems
      # for this particular measure.     
      if air_loop.supplyComponents("OS:Fan:VariableVolume".to_IddObjectType).size == 0
        runner.registerInfo("DCV not applicable to '#{air_loop.name}' because it is not a VAV system.")
        next
      end
      
      # DCV is applicable to this airloop
      # Change the min flow rate in the controller outdoor air
      controller_oa.setMinimumOutdoorAirFlowRate(0.0)
       
      # Enable DCV in the controller mechanical ventilation
      controller_mv.setDemandControlledVentilation(true)
      runner.registerInfo("Enabled DCV for '#{air_loop.name}'.")
      air_loops_dcv_added << air_loop
            
    end # Next air loop  
      
    # If the model has no air loops, flag as Not Applicable
    if air_loops.size == 0
      runner.registerAsNotApplicable("Not Applicable - The model has no air loops.")
      return true
    end
    
    # If all air loops already have DCV, flag as Not Applicable
    if air_loops_already_dcv.size == air_loops.size
      runner.registerAsNotApplicable("Not Applicable - All air loops already have DCV.")
      return true
    end    

    # If no air loops are eligible for DCV, flag as Not Applicable
    if air_loops_dcv_added.size == 0
      runner.registerAsNotApplicable("Not Applicable - DCV was not applicable to any air loops in the model.")
      return true
    end

    # Report the initial condition
    runner.registerInitialCondition("Model has #{air_loops.size} air loops, #{air_loops_already_dcv.size} of which already have DCV enabled.")
    
    # Report the final condition
    runner.registerFinalCondition("#{air_loops_dcv_added.size} air loops had DCV enabled.")
      
    return true

  end
  
end

# register the measure to be used by the application
DemandControlVentilationMetalOxideSensors.new.registerWithApplication
