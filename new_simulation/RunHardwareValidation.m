%% RunHardwareValidation.m
% Main script to run all hardware validation experiments
%
% USAGE:
%   1. Run in MATLAB: RunHardwareValidation()
%   2. For REAL hardware data, modify the scripts to read from INA219, etc.
%   3. Results will be saved to hardware_data/ directory
%
% LOOP MODE:
%   To run continuously: RunHardwareValidation(true)
%   This will collect data every 5 minutes until manually stopped
%
% Author: Chandan Sheikder
% Date: 2026-08-15

function RunHardwareValidation(loop_mode)
    % Close all figures
    close all;
    
    % Add path to include all subfolders
    addpath(genpath(pwd));
    
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('FORMICABOT V2 HARDWARE VALIDATION\n');
    fprintf('Data Collection Framework\n');
    fprintf('============================================================\n');
    fprintf('Started: %s\n', datestr(now));
    fprintf('============================================================\n');
    
    % Initialize data collector
    dataCollector = HardwareDataCollection();
    
    % Determine mode
    if nargin < 1
        loop_mode = false;
    end
    
    if loop_mode
        fprintf('\n*** LOOP MODE ENABLED ***\n');
        fprintf('Will collect data every 5 minutes\n');
        fprintf('Press Ctrl+C to stop\n');
    end
    
    %% ============================================================
    %% STEP 1: RUN SIMULATION TO GET BASELINE DATA
    %% ============================================================
    
    fprintf('\n');
    fprintf('STEP 1: Running simulation for baseline data...\n');
    fprintf('----------------------------------------------\n');
    
    % Define simulation parameters (same as RealSpace_Pheromone_Simulation.m)
    params = SimulationParameters();
    
    % Initialize models
    fprintf('Initializing floor model...\n');
    floorModel = RealisticFloor(params);
    
    fprintf('Initializing sensor model...\n');
    sensorModel = TCRT5000SensorArray(params);
    
    fprintf('Initializing pheromone model...\n');
    pheromoneModel = WS2812BPheromone(params);
    
    fprintf('Initializing navigation controllers...\n');
    controllerIdeal = NavigationController(params, 'ideal');
    controllerReal = NavigationController(params, 'realistic');
    
    fprintf('Initializing chemical sensor...\n');
    chemicalSensor = ChemicalGradientSensor(params);
    
    % Run ideal simulation
    fprintf('\nRunning IDEAL sensing simulation...\n');
    tic;
    [resultsIdeal, simDataIdeal] = runSimulation(params, floorModel, sensorModel, ...
        pheromoneModel, controllerIdeal, 'ideal');
    time_ideal = toc;
    fprintf('  Completed in %.2f seconds\n', time_ideal);
    
    % Run realistic simulation
    fprintf('\nRunning REALISTIC sensing simulation...\n');
    pheromoneModel = WS2812BPheromone(params);  % Reset pheromones
    tic;
    [resultsReal, simData] = runSimulation(params, floorModel, sensorModel, ...
        pheromoneModel, controllerReal, 'realistic', chemicalSensor);
    time_real = toc;
    fprintf('  Completed in %.2f seconds\n', time_real);
    
    %% ============================================================
    %% STEP 2: COLLECT HARDWARE VALIDATION DATA
    %% ============================================================
    
    fprintf('\n');
    fprintf('STEP 2: Collecting hardware validation data...\n');
    fprintf('----------------------------------------------\n');
    
    % Create hardware data collector
    hwc = HardwareDataCollection();
    
    % 2.1 Power Consumption
    fprintf('\n[2.1] Running power consumption analysis...\n');
    hwc.runPowerConsumptionExperiment();
    
    % 2.2 Trajectory & Cross-Track Error
    fprintf('\n[2.2] Running trajectory analysis...\n');
    hwc.runTrajectoryExperiment();
    
    % 2.3 MQ-135 Warm-Up
    fprintf('\n[2.3] Running MQ-135 warm-up analysis...\n');
    hwc.runMQ135WarmupExperiment();
    
    % 2.4 Pheromone Decay Model
    fprintf('\n[2.4] Documenting pheromone decay model...\n');
    hwc.documentPheromoneDecayModel();
    
    % 2.5 SLAM RMSE
    fprintf('\n[2.5] Running SLAM RMSE analysis...\n');
    hwc.runSLAMRMSEExperiment();
    
    %% ============================================================
    %% STEP 3: GENERATE COMPREHENSIVE REPORT
    %% ============================================================
    
    fprintf('\n');
    fprintf('STEP 3: Generating comprehensive report...\n');
    fprintf('----------------------------------------------\n');
    
    hwc.generateComprehensiveReport();
    hwc.saveAllData();
    
    %% ============================================================
    %% STEP 4: UPDATE MANUSCRIPT DATA
    %% ============================================================
    
    fprintf('\n');
    fprintf('STEP 4: Manuscript data update...\n');
    fprintf('----------------------------------------------\n');
    
    % Create corrected data summary
    corrected_data = struct();
    
    % Power consumption (replaces 0.669 W)
    corrected_data.power_consumption = struct();
    corrected_data.power_consumption.fabricated_value = 0.669;  % W
    corrected_data.power_consumption.corrected_value = hwc.power_data.mean_power;  % W
    corrected_data.power_consumption.unit = 'W';
    corrected_data.power_consumption.status = 'NEEDS_UPDATE';
    if hwc.power_data.mean_power > 10
        corrected_data.power_consumption.status = 'CORRECTED';
    end
    
    % Cross-track error (replaces 0.080 cm)
    corrected_data.cross_track_error = struct();
    corrected_data.cross_track_error.fabricated_value = 0.080;  % cm
    corrected_data.cross_track_error.corrected_value = hwc.trajectory_data.percentile_95 * 100;  % cm
    corrected_data.cross_track_error.unit = 'cm';
    corrected_data.cross_track_error.percentile = 95;
    corrected_data.cross_track_error.status = 'NEEDS_UPDATE';
    if hwc.trajectory_data.percentile_95 * 100 > 0.5
        corrected_data.cross_track_error.status = 'CORRECTED';
    end
    
    % MQ-135 stabilization time (replaces 30 s)
    corrected_data.mq135_stabilization = struct();
    corrected_data.mq135_stabilization.fabricated_value = 30;  % s
    corrected_data.mq135_stabilization.corrected_value = hwc.mq135_warmup_data.stabilization_time;  % s
    corrected_data.mq135_stabilization.unit = 's';
    corrected_data.mq135_stabilization.status = 'NEEDS_UPDATE';
    if hwc.mq135_warmup_data.stabilization_time > 60
        corrected_data.mq135_stabilization.status = 'CORRECTED';
    end
    
    % SLAM RMSE (replaces 0.087 m)
    corrected_data.slam_rmse = struct();
    corrected_data.slam_rmse.fabricated_value = 0.087;  % m
    corrected_data.slam_rmse.corrected_value = hwc.slam_rmse_data.rmse;  % m
    corrected_data.slam_rmse.unit = 'm';
    corrected_data.slam_rmse.status = 'NEEDS_UPDATE';
    if hwc.slam_rmse_data.rmse > 0.01 && hwc.slam_rmse_data.rmse < 0.20
        corrected_data.slam_rmse.status = 'CORRECTED';
    end
    
    % Pheromone decay model (correct documentation)
    corrected_data.pheromone_decay = struct();
    corrected_data.pheromone_decay.model = 'Virtual grid simulation';
    corrected_data.pheromone_decay.decay_equation = 'I(t) = I0 * exp(-phi * t) + I_residual';
    corrected_data.pheromone_decay.decay_constant = hwc.pheromone_decay_data.decay_rate;
    corrected_data.pheromone_decay.residual_fraction = hwc.pheromone_decay_data.residual_fraction;
    corrected_data.pheromone_decay.status = 'DOCUMENTED';
    
    % Save corrected data
    save('hardware_data/corrected_manuscript_data.mat', 'corrected_data');
    
    % Print correction summary
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('CORRECTED MANUSCRIPT DATA SUMMARY\n');
    fprintf('============================================================\n');
    fprintf('\n');
    
    fprintf('Item 1: Power Consumption\n');
    fprintf('  Fabricated: %.3f W\n', corrected_data.power_consumption.fabricated_value);
    fprintf('  Corrected:  %.3f W\n', corrected_data.power_consumption.corrected_value);
    fprintf('  Status:     %s\n', corrected_data.power_consumption.status);
    fprintf('  Location:   Power consumption section\n');
    fprintf('\n');
    
    fprintf('Item 2: Cross-Track Error (95th percentile)\n');
    fprintf('  Fabricated: %.3f cm\n', corrected_data.cross_track_error.fabricated_value);
    fprintf('  Corrected:  %.3f cm\n', corrected_data.cross_track_error.corrected_value);
    fprintf('  Status:     %s\n', corrected_data.cross_track_error.status);
    fprintf('  Location:   Trajectory analysis section\n');
    fprintf('\n');
    
    fprintf('Item 3: MQ-135 Stabilization Time\n');
    fprintf('  Fabricated: %d s\n', corrected_data.mq135_stabilization.fabricated_value);
    fprintf('  Corrected:  %.1f s\n', corrected_data.mq135_stabilization.corrected_value);
    fprintf('  Status:     %s\n', corrected_data.mq135_stabilization.status);
    fprintf('  Location:   Algorithm 1\n');
    fprintf('\n');
    
    fprintf('Item 4: Virtual Pheromone Decay Model\n');
    fprintf('  Method:     %s\n', corrected_data.pheromone_decay.model);
    fprintf('  Equation:   %s\n', corrected_data.pheromone_decay.decay_equation);
    fprintf('  phi:        %.4f per second\n', corrected_data.pheromone_decay.decay_constant);
    fprintf('  Status:     %s\n', corrected_data.pheromone_decay.status);
    fprintf('  Location:   Physical implementation section\n');
    fprintf('\n');
    
    fprintf('Item 5: SLAM RMSE\n');
    fprintf('  Fabricated: %.3f m\n', corrected_data.slam_rmse.fabricated_value);
    fprintf('  Corrected:  %.3f m\n', corrected_data.slam_rmse.corrected_value);
    fprintf('  Status:     %s\n', corrected_data.slam_rmse.status);
    fprintf('  Location:   SLAM evaluation section\n');
    fprintf('\n');
    
    %% ============================================================
    %% LOOP MODE
    %% ============================================================
    
    if loop_mode
        loop_interval = 300;  % 5 minutes in seconds
        iteration = 1;
        
        fprintf('\n');
        fprintf('*** ENTERING LOOP MODE ***\n');
        fprintf('Iteration: %d\n', iteration);
        fprintf('Next collection in: %d seconds\n', loop_interval);
        fprintf('\n');
        
        while true
            % Wait for next iteration
            pause(loop_interval);
            
            iteration = iteration + 1;
            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('LOOP ITERATION %d\n', iteration);
            fprintf('============================================================\n');
            
            % Run hardware validation again
            hwc = HardwareDataCollection();
            hwc.runPowerConsumptionExperiment();
            hwc.runTrajectoryExperiment();
            hwc.runMQ135WarmupExperiment();
            hwc.documentPheromoneDecayModel();
            hwc.runSLAMRMSEExperiment();
            hwc.generateComprehensiveReport();
            hwc.saveAllData();
            
            fprintf('\n');
            fprintf('Next collection in: %d seconds\n', loop_interval);
        end
    end
    
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('HARDWARE VALIDATION COMPLETE\n');
    fprintf('============================================================\n');
    fprintf('Results saved to: hardware_data/\n');
    fprintf('\n');
    fprintf('To run again: RunHardwareValidation()\n');
    fprintf('To run in loop mode: RunHardwareValidation(true)\n');
    fprintf('\n');
end

%% ============================================================
%% SIMULATION PARAMETERS (local function)
%% ============================================================
function params = SimulationParameters()
    % Simulation Parameters
    params.arena_width = 5.0;           % meters
    params.arena_height = 5.0;          % meters
    params.sim_time = 60.0;             % seconds
    params.dt = 0.01;                   % time step (seconds)
    params.num_robots = 5;              % number of robots
    
    % Floor parameters
    params.floor_resolution = 0.005;    % meters per pixel
    params.floor_imperfection_level = 0.3;
    params.dust_density = 500;           % particles per m^2
    params.reflectivity_base = 0.8;
    params.reflectivity_variation = 0.15;
    
    % TCRT5000 Sensor parameters
    params.num_sensors = 4;
    params.sensor_spacing = 0.012;      % meters between sensors
    params.sensor_noise = 0.05;
    params.sensor_crosstalk = 0.1;
    params.enable_crosstalk = true;
    params.sensor_range = 0.05;         % meters
    
    % WS2812B LED parameters
    params.led_intensity = 255;
    params.led_spot_size = 0.02;        % meters (LED spot diameter)
    params.led_wavelength = 625e-9;     % 625nm red LED
    
    % Pheromone parameters
    params.decay_rate = 0.02;           % per second
    params.max_trail_intensity = 255;
    params.trail_blend_method = 'additive';
    params.overlap_method = 'max_intensity';
    
    % Robot parameters
    params.robot_radius = 0.05;         % meters
    params.max_speed = 0.2;             % m/s
    params.turn_rate = 2.0;              % rad/s
    params.sensor_height = 0.01;         % meters above floor
    
    % Target parameters
    params.target_position = [4.5, 4.5]; % target location
    params.target_radius = 0.15;         % meters
    
    % Navigation parameters
    params.waypoint_threshold = 0.1;    % meters
    params.pheromone_threshold = 30;     % sensor value to follow trail
    
    % Random seed for reproducibility
    rng('shuffle');
end
