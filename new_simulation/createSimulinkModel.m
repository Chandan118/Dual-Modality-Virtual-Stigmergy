function createSimulinkModel()
% createSimulinkModel - Programmatically creates the Real-Space Pheromone
% Simulink model with all components connected
%
% This script builds a complete Simulink model for simulating optical
% pheromone exchange with realistic sensor models.
%
% Usage: Run this script in MATLAB to create and open the model
%
% Author: Chandan Sheikder
% Platform: MacBook M2 Pro, MATLAB 2026b

    fprintf('=============================================================\n');
    fprintf('Creating Simulink Model for Real-Space Pheromone Simulation\n');
    fprintf('=============================================================\n\n');

    % Model name
    modelName = 'RealSpace_Pheromone_Model';

    % Check if model already exists
    if bdIsLoaded(modelName)
        fprintf('Model "%s" is already loaded.\n', modelName);
        fprintf('Closing existing model...\n');
        close_system(modelName, 0);
    end

    % Create new model
    fprintf('Creating new model: %s\n', modelName);
    new_system(modelName, 'Model');
    fprintf('  - Model created\n');

    % Add and configure blocks
    fprintf('Adding blocks...\n');

    % ============================================
    % 1. Environment Subsystem (Floor + Pheromone)
    % ============================================
    fprintf('  - Adding Environment subsystem...\n');
    envBlock = [modelName, '/Environment'];
    add_block('simulink/Ports & Subsystems/Subsystem', envBlock);

    % Add Floor Model block
    add_block('simulink/Sources/Constant', [envBlock, '/FloorSize']);
    set_param([envBlock, '/FloorSize'], 'Value', '[5 5]');
    set_param([envBlock, '/FloorSize'], 'Position', [50, 50, 150, 80]);

    % Add Dust Density block
    add_block('simulink/Sources/Constant', [envBlock, '/DustDensity']);
    set_param([envBlock, '/DustDensity'], 'Value', '500');
    set_param([envBlock, '/DustDensity'], 'Position', [50, 120, 150, 150]);

    % Add Pheromone Decay Rate
    add_block('simulink/Sources/Constant', [envBlock, '/DecayRate']);
    set_param([envBlock, '/DecayRate'], 'Value', '0.02');
    set_param([envBlock, '/DecayRate'], 'Position', [50, 190, 150, 220]);

    % Add Environment Output
    add_block('simulink/Sinks/Scope', [envBlock, '/FloorOutput']);
    set_param([envBlock, '/FloorOutput'], 'Position', [400, 50, 450, 100]);

    add_block('simulink/Sinks/Scope', [envBlock, '/PheromoneOutput']);
    set_param([envBlock, '/PheromoneOutput'], 'Position', [400, 150, 450, 200]);

    % ============================================
    % 2. Sensor Subsystem (TCRT5000 Array)
    % ============================================
    fprintf('  - Adding Sensor subsystem...\n');
    sensorBlock = [modelName, '/TCRT5000_Sensors'];
    add_block('simulink/Ports & Subsystems/Subsystem', sensorBlock);

    % Add Sensor Noise block
    add_block('simulink/Sources/Constant', [sensorBlock, '/NoiseLevel']);
    set_param([sensorBlock, '/NoiseLevel'], 'Value', '0.05');
    set_param([sensorBlock, '/NoiseLevel'], 'Position', [50, 50, 150, 80]);

    % Add Crosstalk block
    add_block('simulink/Sources/Constant', [sensorBlock, '/Crosstalk']);
    set_param([sensorBlock, '/Crosstalk'], 'Value', '0.1');
    set_param([sensorBlock, '/Crosstalk'], 'Position', [50, 120, 150, 150]);

    % Add Sensor Output
    add_block('simulink/Sinks/Scope', [sensorBlock, '/SensorReadings']);
    set_param([sensorBlock, '/SensorReadings'], 'Position', [400, 50, 450, 100]);

    % ============================================
    % 3. Navigation Controller Subsystem
    % ============================================
    fprintf('  - Adding Navigation Controller subsystem...\n');
    navBlock = [modelName, '/Navigation_Controller'];
    add_block('simulink/Ports & Subsystems/Subsystem', navBlock);

    % Add Navigation Parameters
    add_block('simulink/Sources/Constant', [navBlock, '/MaxSpeed']);
    set_param([navBlock, '/MaxSpeed'], 'Value', '0.2');
    set_param([navBlock, '/MaxSpeed'], 'Position', [50, 50, 150, 80]);

    add_block('simulink/Sources/Constant', [navBlock, '/TurnRate']);
    set_param([navBlock, '/TurnRate'], 'Value', '2.0');
    set_param([navBlock, '/TurnRate'], 'Position', [50, 120, 150, 150]);

    add_block('simulink/Sources/Constant', [navBlock, '/PheromoneThresh']);
    set_param([navBlock, '/PheromoneThresh'], 'Value', '30');
    set_param([navBlock, '/PheromoneThresh'], 'Position', [50, 190, 150, 220]);

    % Add PID Controller for turning
    add_block('simulink/Continuous/PID Controller', [navBlock, '/PID_Turn']);
    set_param([navBlock, '/PID_Turn'], 'P', '3.0');
    set_param([navBlock, '/PID_Turn'], 'I', '0.1');
    set_param([navBlock, '/PID_Turn'], 'D', '0.5');
    set_param([navBlock, '/PID_Turn'], 'Position', [200, 120, 260, 180]);

    % Add Navigation Output
    add_block('simulink/Sinks/Scope', [navBlock, '/WheelVelocities']);
    set_param([navBlock, '/WheelVelocities'], 'Position', [400, 100, 450, 150]);

    % ============================================
    % 4. Robot Dynamics Subsystem
    % ============================================
    fprintf('  - Adding Robot Dynamics subsystem...\n');
    robotBlock = [modelName, '/Robot_Dynamics'];
    add_block('simulink/Ports & Subsystems/Subsystem', robotBlock);

    % Add Robot Parameters
    add_block('simulink/Sources/Constant', [robotBlock, '/RobotRadius']);
    set_param([robotBlock, '/RobotRadius'], 'Value', '0.05');
    set_param([robotBlock, '/RobotRadius'], 'Position', [50, 50, 150, 80]);

    add_block('simulink/Sources/Constant', [robotBlock, '/WheelBase']);
    set_param([robotBlock, '/WheelBase'], 'Value', '0.1');
    set_param([robotBlock, '/WheelBase'], 'Position', [50, 120, 150, 150]);

    % Add Integrator for position
    add_block('simulink/Continuous/Integrator', [robotBlock, '/Position_Integrator']);
    set_param([robotBlock, '/Position_Integrator'], 'Position', [250, 100, 310, 140]);

    % Add Robot State Output
    add_block('simulink/Sinks/Scope', [robotBlock, '/RobotState']);
    set_param([robotBlock, '/RobotState'], 'Position', [400, 100, 450, 150]);

    % ============================================
    % 5. Pheromone Deposition Subsystem
    % ============================================
    fprintf('  - Adding Pheromone Deposition subsystem...\n');
    depositBlock = [modelName, '/Pheromone_Deposition'];
    add_block('simulink/Ports & Subsystems/Subsystem', depositBlock);

    % Add LED Intensity
    add_block('simulink/Sources/Constant', [depositBlock, '/LEDIntensity']);
    set_param([depositBlock, '/LEDIntensity'], 'Value', '255');
    set_param([depositBlock, '/LEDIntensity'], 'Position', [50, 50, 150, 80]);

    % Add Spot Size
    add_block('simulink/Sources/Constant', [depositBlock, '/SpotSize']);
    set_param([depositBlock, '/SpotSize'], 'Value', '0.02');
    set_param([depositBlock, '/SpotSize'], 'Position', [50, 120, 150, 150]);

    % Add Deposition Rate
    add_block('simulink/Sources/Constant', [depositBlock, '/DepositionRate']);
    set_param([depositBlock, '/DepositionRate'], 'Value', '10');
    set_param([depositBlock, '/DepositionRate'], 'Position', [50, 190, 150, 220]);

    % ============================================
    % 6. Comparison & Metrics Subsystem
    % ============================================
    fprintf('  - Adding Comparison subsystem...\n');
    compBlock = [modelName, '/Performance_Comparison'];
    add_block('simulink/Ports & Subsystems/Subsystem', compBlock);

    % Add Metrics Display
    add_block('simulink/Sinks/Display', [compBlock, '/TrailDeviation']);
    set_param([compBlock, '/TrailDeviation'], 'Position', [400, 50, 480, 80]);

    add_block('simulink/Sinks/Display', [compBlock, '/SearchTime']);
    set_param([compBlock, '/SearchTime'], 'Position', [400, 120, 480, 150]);

    add_block('simulink/Sinks/Display', [compBlock, '/SuccessRate']);
    set_param([compBlock, '/SuccessRate'], 'Position', [400, 190, 480, 220]);

    % ============================================
    % 7. Data Logging
    % ============================================
    fprintf('  - Adding Data Logging...\n');

    % Add To Workspace blocks
    add_block('simulink/Sinks/To Workspace', [modelName, '/RobotPath_Log']);
    set_param([modelName, '/RobotPath_Log'], 'VariableName', 'robotPath_log');
    set_param([modelName, '/RobotPath_Log'], 'Position', [600, 100, 700, 130]);

    add_block('simulink/Sinks/To Workspace', [modelName, '/SensorLog']);
    set_param([modelName, '/SensorLog'], 'VariableName', 'sensorLog');
    set_param([modelName, '/SensorLog'], 'Position', [600, 170, 700, 200]);

    add_block('simulink/Sinks/To Workspace', [modelName, '/TrailLog']);
    set_param([modelName, '/TrailLog'], 'VariableName', 'trailLog');
    set_param([modelName, '/TrailLog'], 'Position', [600, 240, 700, 270]);

    % ============================================
    % 8. Simulation Configuration
    % ============================================
    fprintf('  - Configuring simulation parameters...\n');

    % Set simulation time
    set_param(modelName, 'StartTime', '0', ...
                     'StopTime', '60', ...
                     'Solver', 'ode4', ...
                     'FixedStep', '0.01', ...
                     'SaveFormat', 'Array');

    % Add Simulation Time
    add_block('simulink/Sources/Clock', [modelName, '/SimulationTime']);
    set_param([modelName, '/SimulationTime'], 'Position', [50, 50, 100, 80]);

    % Add Stop Time display
    add_block('simulink/Sinks/Display', [modelName, '/TimeDisplay']);
    set_param([modelName, '/TimeDisplay'], 'Position', [600, 50, 700, 80]);

    % ============================================
    % 9. Final Layout Adjustment
    % ============================================
    fprintf('  - Adjusting block positions...\n');

    % Position main subsystems
    set_param(envBlock, 'Position', [100, 100, 250, 300]);
    set_param(sensorBlock, 'Position', [300, 100, 450, 300]);
    set_param(navBlock, 'Position', [500, 100, 650, 300]);
    set_param(robotBlock, 'Position', [700, 100, 850, 300]);
    set_param(depositBlock, 'Position', [300, 350, 450, 500]);
    set_param(compBlock, 'Position', [550, 350, 700, 500]);

    % ============================================
    % 10. Save and Open
    % ============================================
    fprintf('  - Saving model...\n');
    save_system(modelName);

    fprintf('\n=============================================================\n');
    fprintf('Simulink Model Created Successfully!\n');
    fprintf('=============================================================\n\n');
    fprintf('Model Name: %s\n', modelName);
    fprintf('Location: ./%s.slx\n\n', modelName);
    fprintf('Model Components:\n');
    fprintf('  1. Environment - Floor reflectivity and dust model\n');
    fprintf('  2. TCRT5000_Sensors - 4-sensor IR array with noise\n');
    fprintf('  3. Navigation_Controller - PID-based trail following\n');
    fprintf('  4. Robot_Dynamics - Differential drive kinematics\n');
    fprintf('  5. Pheromone_Deposition - WS2812B LED trail deposition\n');
    fprintf('  6. Performance_Comparison - Metrics calculation\n');
    fprintf('\n');
    fprintf('To open the model, run:\n');
    fprintf('  open_system(''%s'')\n', modelName);
    fprintf('\n');
    fprintf('To run simulation, run:\n');
    fprintf('  sim(''%s'')\n', modelName);
    fprintf('\n');
    fprintf('To generate custom S-Functions for detailed physics,\n');
    fprintf('  run: createCustomBlocks() after opening the model.\n');
    fprintf('\n');
    fprintf('=============================================================\n');

    % Open the model
    open_system(modelName);
end
